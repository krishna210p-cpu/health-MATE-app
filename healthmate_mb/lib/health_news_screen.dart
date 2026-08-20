import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_localizations.dart';
import 'language_provider.dart';
import 'services/news_service.dart';
import 'models/article.dart';

class HealthNewsScreen extends StatefulWidget {
  const HealthNewsScreen({Key? key}) : super(key: key);

  @override
  State<HealthNewsScreen> createState() => _HealthNewsScreenState();
}

class _HealthNewsScreenState extends State<HealthNewsScreen> {
  final NewsService _newsService = NewsService();

  List<Article> _articles = [];
  bool _isLoading = false;
  String _currentLang = 'en';
  bool _showingFallbackEnglish = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LanguageProvider>(context, listen: false);
      _currentLang = (provider.languageCode ?? 'en');
      _loadArticles();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<LanguageProvider>(context);
    final lang = (provider.languageCode ?? 'en');
    if (lang != _currentLang) {
      _currentLang = lang;
      _loadArticles();
    }
  }

  Future<void> _loadArticles({bool forceRefresh = false}) async {
    final langKey = (_currentLang.isEmpty) ? 'en' : _currentLang;

    if (forceRefresh) {
      try {
        final fresh = await _newsService.getArticles(forceRefresh: true, lang: langKey).timeout(const Duration(seconds: 10));
        if (fresh.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _articles = fresh;
            _showingFallbackEnglish = false;
            _isLoading = false;
          });
        }
        return;
      } catch (_) {
        // fall through to try cache
      }
    }

    setState(() {
      _isLoading = _articles.isEmpty;
    });

    // 1) Cache for selected language
    final cachedForLang = await _newsService.loadCachedArticlesForLang(langKey);
    if (cachedForLang.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _articles = cachedForLang;
        _isLoading = false;
        _showingFallbackEnglish = false;
      });
      _refreshInBackground(langKey);
      return;
    }

    // 2) English cache fallback
    if (langKey != 'en') {
      final cachedEn = await _newsService.loadCachedArticlesForLang('en');
      if (cachedEn.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _articles = cachedEn;
          _isLoading = false;
          _showingFallbackEnglish = true;
        });
        // Attempt to translate the English cache into the requested language in background
        // and update UI when translation completes (so user sees content in their language).
        Future(() async {
          try {
            final translated = await _newsService.translateAndCacheFromEnglish(langKey);
            if (translated.isNotEmpty) {
              if (!mounted) return;
              setState(() {
                _articles = translated;
                _showingFallbackEnglish = false;
              });
            }
          } catch (_) {}
        });
        _refreshInBackground(langKey);
        return;
      }
    }

    // 3) Quick network attempt
    try {
      final fresh = await _newsService.getArticles(forceRefresh: false, lang: langKey).timeout(const Duration(seconds: 8));
      if (fresh.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _articles = fresh;
          _isLoading = false;
          _showingFallbackEnglish = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
        _articles = [];
        _showingFallbackEnglish = false;
      });
    }
    _refreshInBackground(langKey);
  }

  void _refreshInBackground(String langKey) {
    Future(() async {
      try {
        final fresh = await _newsService.getArticles(forceRefresh: true, lang: langKey).timeout(const Duration(seconds: 12));
        if (fresh.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _articles = fresh;
            _showingFallbackEnglish = false;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _onRefresh() async => _loadArticles(forceRefresh: true);

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context).t('topStories');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_articles.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(AppLocalizations.of(context).t('no_news_available')),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: () => _loadArticles(forceRefresh: true), child: Text(AppLocalizations.of(context).t('try_again'))),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _articles.length + (_showingFallbackEnglish ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (_showingFallbackEnglish && index == 0) {
          return Card(
            color: Colors.yellow[50],
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.black54),
              title: Text(AppLocalizations.of(context).t('english_fallback_title')),
              subtitle: Text(AppLocalizations.of(context).t('english_fallback_subtitle')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.translate), tooltip: AppLocalizations.of(context).t('translate'), onPressed: () async {
                    // Attempt to translate cached English articles into the current language
                    final target = (_currentLang.isEmpty) ? 'en' : _currentLang;
                    if (target == 'en') return;
                    if (!mounted) return;
                    setState(() { _isLoading = true; });
                    try {
                      final translated = await _newsService.translateAndCacheFromEnglish(target);
                      if (translated.isNotEmpty) {
                        if (!mounted) return;
                        setState(() {
                          _articles = translated;
                          _showingFallbackEnglish = false;
                        });
                      }
                    } catch (_) {}
                    if (!mounted) return;
                    setState(() { _isLoading = false; });
                  }),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadArticles(forceRefresh: true)),
                ],
              ),
            ),
          );
        }

        final article = _articles[index - (_showingFallbackEnglish ? 1 : 0)];
  // sanitize title and summary to remove HTML tags/entities
  final title = _stripHtml(article.title);
  final summary = _stripHtml(article.summary);
        return Card(
          child: InkWell(
            onTap: () async {
              final link = article.link ?? '';
              if (link.isEmpty) return;
              try {
                var candidate = link.trim();
                if (candidate.startsWith('//')) candidate = 'https:$candidate';
                if (!candidate.startsWith('http')) candidate = 'https://$candidate';
                final uri = Uri.parse(candidate);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // leading placeholder
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.shield, color: Colors.grey, size: 36),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text('${article.source} ${_formatShortDate(article.publishedDate)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.open_in_new, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _stripHtml(String raw) {
    var s = raw;
    try {
      // Remove HTML tags
      s = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
      // Replace common HTML entities
      s = s.replaceAll('&nbsp;', ' ');
      s = s.replaceAll('&amp;', '&');
      s = s.replaceAll('&quot;', '"');
      s = s.replaceAll('&#039;', "'");
      // Remove URLs which can cause unbreakable overflow
      s = s.replaceAll(RegExp(r'https?:\/\/\S+'), '');
      s = s.replaceAll(RegExp(r'www\.\S+'), '');
      // Collapse multiple whitespace
      s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) {}
    return s;
  }
}

  String _formatShortDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
