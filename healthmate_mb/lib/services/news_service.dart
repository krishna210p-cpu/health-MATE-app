import 'package:http/http.dart' as http;
import '../models/article.dart';
import 'package:hive/hive.dart';
import 'package:xml/xml.dart' as xml;
// Use a lightweight HTTP-based translation helper (LibreTranslate) to avoid package conflicts
import 'dart:convert' as convert;

class NewsService {
  static const _cacheBox = 'articles_box';

  // Free public sources (RSS preferred). If RSS not available, we'll try a light HTML fallback.
  // Exact public sources (RSS where available). MOHFW doesn't provide a stable RSS
  // on their /updates page, so we use the updates page as HTML fallback.
  final List<Map<String, String>> _sources = [
    {'name': 'MOHFW', 'url': 'https://www.mohfw.gov.in/updates', 'type': 'html', 'lang': 'en'},
    {'name': 'PIB', 'url': 'https://pib.gov.in/PressReleaseRSS.aspx?MinID=36', 'type': 'rss', 'lang': 'en'},
    {'name': 'WHO India', 'url': 'https://www.who.int/feeds/entity/india/en/rss.xml', 'type': 'rss', 'lang': 'en'},
    {'name': 'ICMR', 'url': 'https://icmr.nic.in/rss.xml', 'type': 'rss', 'lang': 'en'},
    {'name': 'Maharashtra Health', 'url': 'https://arogya.maharashtra.gov.in/rss.xml', 'type': 'rss', 'lang': 'en'},
  ];

  Future<List<Article>> fetchLatestArticles({String? lang, String? scope}) async {
    final results = <Article>[];

    // Try Google News RSS search first for fresher, aggregated headlines (falls back to configured sources)
    try {
      final q = Uri.encodeComponent('health ${lang == null || lang == 'en' ? 'India' : ''}');
      // Map language to Google News hl/ceid params
      final langMap = {
        'en': {'hl': 'en-IN', 'ceid': 'IN:en'},
        'hi': {'hl': 'hi', 'ceid': 'IN:hi'},
        'mr': {'hl': 'mr', 'ceid': 'IN:mr'},
        'bn': {'hl': 'bn', 'ceid': 'IN:bn'},
        'ta': {'hl': 'ta', 'ceid': 'IN:ta'},
        'gu': {'hl': 'gu', 'ceid': 'IN:gu'},
      };
      final p = (lang != null && langMap.containsKey(lang)) ? langMap[lang]! : langMap['en']!;
      final gUrl = 'https://news.google.com/rss/search?q=$q&hl=${p['hl']}&gl=IN&ceid=${p['ceid']}';
      // ignore: avoid_print
      print('NewsService: fetching GoogleNews URL=$gUrl (lang=${lang ?? 'en'})');
      final gResp = await http.get(Uri.parse(gUrl)).timeout(const Duration(seconds: 6));
      if (gResp.statusCode == 200 && gResp.body.isNotEmpty) {
        try {
          final doc = xml.XmlDocument.parse(gResp.body);
          final items = doc.findAllElements('item');
          for (final n in items) {
            final title = n.getElement('title')?.innerText.trim() ?? '';
            final desc = n.getElement('description')?.innerText.trim() ?? '';
            final pubRaw = n.getElement('pubDate')?.innerText.trim() ?? '';
            var link = n.getElement('link')?.innerText.trim() ?? '';
            link = _normalizeLink(link, 'https://news.google.com');
            results.add(Article.fromMap({
              'title': title,
              'summary': desc,
              'source': 'GoogleNews',
              'publishedAt': pubRaw.isNotEmpty ? (DateTime.tryParse(pubRaw)?.toIso8601String() ?? DateTime.now().toIso8601String()) : DateTime.now().toIso8601String(),
              'link': link,
              'language': lang ?? 'en',
            }));
          }
          // ignore: avoid_print
          print('NewsService: GoogleNews added ${results.length} items from $gUrl');
        } catch (_) {}
      }
    } catch (_) {}

    for (final src in _sources) {
      final name = src['name']!;
      final url = src['url']!;
      int addedFromSource = 0;
      try {
        // Try RSS when declared
        if (src['type'] == 'rss') {
          final resp = await http.get(Uri.parse(url));
          if (resp.statusCode == 200 && resp.body.isNotEmpty) {
            try {
              final doc = xml.XmlDocument.parse(resp.body);
              final items = doc.findAllElements('item');
              for (final n in items) {
                final title = n.getElement('title')?.innerText.trim() ?? '';
                final desc = n.getElement('description')?.innerText.trim() ?? n.getElement('summary')?.innerText.trim() ?? '';
                final pubRaw = n.getElement('pubDate')?.innerText.trim() ?? n.getElement('published')?.innerText.trim();
                String pub = DateTime.now().toIso8601String();
                if (pubRaw != null) {
                  final parsed = DateTime.tryParse(pubRaw);
                  if (parsed != null) pub = parsed.toIso8601String();
                }
                var link = n.getElement('link')?.innerText.trim() ?? n.getElement('guid')?.innerText.trim() ?? url;
                // Normalize/resolve link against source URL
                link = _normalizeLink(link, url);
                final langDetected = _detectLanguage(title + ' ' + desc, src['lang']);
                var summary = desc;
                // If no summary extracted, try a quick fetch of the article page (short timeout)
                if (summary.isEmpty && link.isNotEmpty) {
                  try {
                    final art = await http.get(Uri.parse(link)).timeout(const Duration(seconds: 4));
                    if (art.statusCode == 200 && art.body.isNotEmpty) {
                      final m = RegExp(r'<p[^>]*>([^<]{50,400})<', caseSensitive: false).firstMatch(art.body);
                      if (m != null) summary = m.group(1) ?? '';
                    }
                  } catch (_) {}
                }

                results.add(Article.fromMap({
                  'title': title,
                  'summary': summary,
                  'source': name,
                  'publishedAt': pub,
                  'link': link,
                  'language': langDetected,
                }));
                addedFromSource++;
              }
            } catch (_) {
              // RSS parse error — we'll fallback to HTML below
            }
          }
        }

        // HTML fallback: either for html sources or if RSS added nothing
        if (src['type'] == 'html' || addedFromSource == 0) {
          final pageResp = await _getWithRetries(Uri.parse(url));
          if (pageResp != null && pageResp.statusCode == 200 && pageResp.body.isNotEmpty) {
            final regex = RegExp(r"""<a[^>]+href=['\"]([^'\"]+)['\"][^>]*>([^<]{10,200})<""", caseSensitive: false);
            final matches = regex.allMatches(pageResp.body);
            for (final m in matches.take(12)) {
              var link = m.group(1) ?? url;
              final title = m.group(2)?.trim() ?? '';
              if (title.length < 8) continue;
              // Resolve relative links against page url
              try {
                link = _normalizeLink(link, url);
              } catch (_) {}
              final langDetected = _detectLanguage(title, src['lang']);
              var summary = '';
              // Try quick fetch of article page for a summary
              try {
                final art = await _getWithRetries(Uri.parse(link), timeout: const Duration(seconds: 4));
                if (art != null && art.statusCode == 200 && art.body.isNotEmpty) {
                  final m2 = RegExp(r'<p[^>]*>([^<]{80,400})<', caseSensitive: false).firstMatch(art.body);
                  if (m2 != null) summary = m2.group(1)?.trim() ?? '';
                }
              } catch (_) {}

              results.add(Article.fromMap({
                'title': title,
                'summary': summary,
                'source': name,
                'publishedAt': DateTime.now().toIso8601String(),
                'link': link,
                'language': langDetected,
              }));
              addedFromSource++;
            }
          }
        }

        // Log per-source counts
        // ignore: avoid_print
        print('NewsService: $name added $addedFromSource items');
      } catch (e) {
        // ignore source errors, but log
        // ignore: avoid_print
        print('NewsService: $name failed: $e');
      }
    }

    // Normalize & dedupe by link/title
    final seen = <String>{};
    final normalized = <Article>[];
    for (final a in results) {
      final key = (a.link ?? a.title).toString();
      if (seen.contains(key)) continue;
      seen.add(key);
      normalized.add(a);
    }

    normalized.sort((a,b) => b.publishedDate.compareTo(a.publishedDate));

    // language filtering with fallback
    if (lang != null && lang.isNotEmpty) {
      final filtered = normalized.where((a) => (a.language ?? 'en') == lang).toList();
      if (filtered.isNotEmpty) return filtered;
      final eng = normalized.where((a) => (a.language ?? 'en') == 'en').toList();
      if (eng.isNotEmpty) return eng;
    }

    return normalized;
  }

  String _normalizeLink(String raw, String baseUrl) {
    if (raw.isEmpty) return baseUrl;
    var s = raw.trim();

    // If the input looks like an anchor tag containing href=, extract the href value
    try {
      final lower = s.toLowerCase();
      final hrefIndex = lower.indexOf('href=');
      if (hrefIndex >= 0) {
        // find the quote character following href=
        int i = hrefIndex + 5;
        // skip whitespace
        while (i < s.length && (s[i] == ' ' || s[i] == '\t')) i++;
        if (i < s.length) {
          final quote = s[i];
          if (quote == '"' || quote == "'") {
            final end = s.indexOf(quote, i + 1);
            if (end > i) s = s.substring(i + 1, end).trim();
          } else {
            // unquoted href value, take until whitespace or >
            int j = i;
            while (j < s.length) {
              final ch = s[j];
              if (ch == ' ' || ch == '\t' || ch == '>' || ch == '"' || ch == "'") break;
              j++;
            }
            s = s.substring(i, j).trim();
          }
        }
      } else {
        // fallback: look for explicit http or www tokens
        final httpIdx = lower.indexOf('http');
        if (httpIdx >= 0) {
          s = s.substring(httpIdx).split(RegExp(r'\s')).first.trim();
        } else {
          final wwwIdx = lower.indexOf('www.');
          if (wwwIdx >= 0) {
            final part = s.substring(wwwIdx).split(RegExp(r'\s')).first.trim();
            s = part.startsWith('http') ? part : 'https://$part';
          }
        }
      }
    } catch (_) {}

  // strip a few common surrounding punctuation characters
  const punct = "()[]\"'`.,;:!";
  while (s.isNotEmpty && punct.contains(s[0])) s = s.substring(1);
  while (s.isNotEmpty && punct.contains(s[s.length - 1])) s = s.substring(0, s.length - 1);

    // decode a couple common HTML entities
    s = s.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#039;', "'");

    // ignore javascript:, mailto:, data: schemes
    final lower = s.toLowerCase();
    if (lower.startsWith('javascript:') || lower.startsWith('mailto:') || lower.startsWith('data:')) {
      return baseUrl;
    }

    // protocol-relative //example.com/path -> https://example.com/path
    if (s.startsWith('//')) s = 'https:$s';

    // If already absolute URL, return normalized string
    try {
      final uri = Uri.parse(s);
      if (uri.hasScheme && uri.isAbsolute) return uri.toString();
    } catch (_) {}

    // Otherwise resolve relative to base URL
    try {
      final base = Uri.parse(baseUrl);
      final resolved = base.resolve(s).toString();
      return resolved;
    } catch (_) {
      // Fallback: if it starts with '/', attach host
      if (s.startsWith('/')) {
        try {
          final b = Uri.parse(baseUrl);
          return '${b.scheme}://${b.host}$s';
        } catch (_) {}
      }
    }

    // Final fallback: ensure it has a scheme
    if (!s.startsWith('http')) s = 'https://$s';
    return s;
  }

  /// Simple GET helper with optional timeout and retries.
  Future<http.Response?> _getWithRetries(Uri uri, {Duration timeout = const Duration(seconds: 8), int retries = 1}) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final resp = await http.get(uri).timeout(timeout);
        return resp;
      } catch (_) {
        if (attempt == retries) return null;
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return null;
  }

  String _detectLanguage(String text, String? sourceLang) {
    final devanagari = RegExp(r'[\u0900-\u097F]');
    if (devanagari.hasMatch(text)) {
      if (sourceLang != null && (sourceLang == 'hi' || sourceLang == 'mr')) return sourceLang;
      return 'hi';
    }
    return 'en';
  }

  Future<List<Article>> getArticles({bool forceRefresh = false, String? lang, String? scope}) async {
    final langKey = (lang == null || lang.isEmpty) ? 'en' : lang;

    // If the caller asked for a forced refresh, try to fetch network first.
    if (forceRefresh) {
      try {
        final fresh = await fetchLatestArticles(lang: lang, scope: scope).timeout(const Duration(seconds: 8));
        // Translate articles when requested language differs
  final processed = await _ensureLanguage(fresh, langKey);
        if (processed.isNotEmpty) await cacheArticlesForLang(processed, langKey);
        return processed;
      } catch (_) {
        // On timeout or error, return cached immediately
        return await loadCachedArticlesForLang(langKey);
      }
    }

    // Default behavior: try network quickly, otherwise return cache.
    try {
      final fresh = await fetchLatestArticles(lang: lang, scope: scope).timeout(const Duration(seconds: 6));
      if (fresh.isNotEmpty) {
  final processed = await _ensureLanguage(fresh, langKey);
        await cacheArticlesForLang(processed, langKey);
        return processed;
      }
    } catch (_) {}

    // Fall back to cache for requested language
    return await loadCachedArticlesForLang(langKey);
  }

  Future<List<Article>> _ensureLanguage(List<Article> articles, String targetLang) async {
    if (targetLang == 'en') return articles;
    final out = <Article>[];
    for (final a in articles) {
      final current = a.language ?? 'en';
      var tTitle = a.title;
      var tSummary = a.summary;
      try {
        if (current != targetLang && tTitle.isNotEmpty) {
          final tt = await _translateText(tTitle, targetLang);
          if (tt != null) tTitle = tt;
        }
        if (current != targetLang && tSummary.isNotEmpty) {
          final ts = await _translateText(tSummary, targetLang);
          if (ts != null) tSummary = ts;
        }
      } catch (e) {
        // translation failed, keep original
      }
      out.add(Article(
        title: tTitle,
        summary: tSummary,
        source: a.source,
        publishedAt: a.publishedAt,
        link: a.link,
        language: targetLang,
      ));
    }
    return out;
  }

  /// Translate short text using LibreTranslate public instance. This is a lightweight fallback and should be replaced
  /// by a hosted translation service for production (or server-side pre-translation).
  Future<String?> _translateText(String text, String targetLang) async {
    try {
      final r = await http.post(Uri.parse('https://libretranslate.de/translate'), headers: {'Content-Type': 'application/json'}, body: convert.jsonEncode({'q': text, 'source': 'auto', 'target': targetLang, 'format': 'text'})).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = convert.jsonDecode(r.body);
        if (j != null && j['translatedText'] != null) return j['translatedText'] as String;
      }
    } catch (_) {}
    return null;
  }

  Future<void> cacheArticlesForLang(List<Article> articles, String langKey) async {
    final box = await Hive.openBox(_cacheBox);
    final limited = articles.take(50).toList();
    final mapped = limited.map((a) => a.toMap()).toList();
    await box.put('latest_$langKey', mapped);
    await box.put('last_updated_$langKey', DateTime.now().toIso8601String());
  }

  Future<List<Article>> loadCachedArticlesForLang(String langKey) async {
    final box = await Hive.openBox(_cacheBox);
    final data = box.get('latest_$langKey', defaultValue: []);
    if (data is List) return data.map((e) => Article.fromMap(Map<String,dynamic>.from(e))).toList();
    return [];
  }

  /// Translate existing English cache into [targetLang], cache it and return translated list.
  /// This is a best-effort helper used when there is no pre-existing translated cache.
  Future<List<Article>> translateAndCacheFromEnglish(String targetLang) async {
    if (targetLang == 'en') return await loadCachedArticlesForLang('en');
    final en = await loadCachedArticlesForLang('en');
    if (en.isEmpty) return [];
    try {
      final translated = await _ensureLanguage(en, targetLang);
      if (translated.isNotEmpty) await cacheArticlesForLang(translated, targetLang);
      return translated;
    } catch (_) {
      return [];
    }
  }

  /// Public list of configured sources (name + url)
  List<Map<String,String>> get sources => List.unmodifiable(_sources);

  Future<void> cacheArticles(List<Article> articles) async {
    final box = await Hive.openBox(_cacheBox);
    final limited = articles.take(50).toList();
    final mapped = limited.map((a) => a.toMap()).toList();
    await box.put('latest', mapped);
    await box.put('last_updated', DateTime.now().toIso8601String());
  }

  Future<List<Article>> loadCachedArticles() async {
    final box = await Hive.openBox(_cacheBox);
    final data = box.get('latest', defaultValue: []);
    if (data is List) return data.map((e) => Article.fromMap(Map<String,dynamic>.from(e))).toList();
    return [];
  }
}
