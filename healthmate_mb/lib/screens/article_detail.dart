import 'package:flutter/material.dart';
import '../models/article.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive/hive.dart';
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class ArticleDetail extends StatelessWidget {
  final Article article;
  const ArticleDetail({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('article_title')),
        actions: [
            IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => SharePlus.instance.share(ShareParams(text: '${article.title}\n\n${article.summary}')),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(article.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('${article.source} • ${article.publishedAt}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: Text(article.summary))),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final box = await Hive.openBox('saved_articles');
                    final list = box.get('items', defaultValue: []) as List;
                    list.insert(0, article.toMap());
                    await box.put('items', list);
                    if (messenger.mounted) messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('saved'))));
                  }, icon: const Icon(Icons.bookmark), label: Text(AppLocalizations.of(context).t('save'))),
                const SizedBox(width: 12),
                ElevatedButton.icon(onPressed: () async {
                  // Open article link in browser if present
                  final url = article.link ?? '';
                  if (url.isEmpty) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('no_updates'))));
                    return;
                  }

                  // Normalize a few common issues before attempting to launch
                  var candidate = url.trim();
                  if (candidate.startsWith('//')) candidate = 'https:$candidate';
                  if (!candidate.startsWith('http')) candidate = 'https://$candidate';

                  try {
                    final uri = Uri.tryParse(candidate);
                    if (uri == null || !uri.hasScheme || !uri.isAbsolute) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('could_not_open'))));
                      return;
                    }
                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!launched && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('could_not_open'))));
                  } catch (_) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('could_not_open'))));
                  }
                }, icon: const Icon(Icons.open_in_new), label: Text(AppLocalizations.of(context).t('read_more'))),
              ],
            )
          ],
        ),
      ),
    );
  }
}
