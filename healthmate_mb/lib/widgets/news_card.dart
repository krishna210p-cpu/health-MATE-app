import 'package:flutter/material.dart';
import '../models/article.dart';
import 'package:hive/hive.dart';
import '../l10n/app_localizations.dart';

class NewsCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onTap;
  const NewsCard({super.key, required this.article, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 84,
                  height: 84,
                  color: Colors.grey[200],
                  child: const Icon(Icons.health_and_safety, size: 40, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // Title takes remaining space and will ellipsize when too long
                      Expanded(
                        child: Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Severity badge is fixed size so it can't force the row to expand
                      if (article.severity.toUpperCase() == 'CRITICAL')
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: SizedBox(
                            width: 70,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                              alignment: Alignment.center,
                              child: const Text('CRITICAL', style: TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                    ],),
                    const SizedBox(height: 6),
                    Text(article.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Source should be allowed to shrink and ellipsize
                        Flexible(
                          child: Text(
                            article.source,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Published date should not force layout -- ellipsize if needed
                        Flexible(
                          child: Text(
                            article.publishedAt.toString(),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Keep popup small and clipped so it can't push the row
                        SizedBox(
                          width: 36,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            onSelected: (v) async {
                              if (v == 'save') {
                                final box = await Hive.openBox('saved_articles');
                                final list = box.get('items', defaultValue: []) as List;
                                list.insert(0, article.toMap());
                                await box.put('items', list);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('saved'))));
                              }
                            },
                            itemBuilder: (_) => [PopupMenuItem(value: 'save', child: Text(AppLocalizations.of(context).t('save')))],
                          ),
                        )
                      ],
                    )
                  ],
                ))
            ],
          ),
        ),
      ),
    );
  }
}
