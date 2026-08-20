class Article {
  final String title;
  final String source;
  final String publishedAt;
  final String summary;
  final String severity; // 'CRITICAL' | 'ADVISORY' | 'TIP'
  final String? link;
  final String? language;
  final String? thumbnail;

  DateTime get publishedDate {
    try {
      return DateTime.parse(publishedAt);
    } catch (_) {
      // Attempt common RFC formats
      try {
        return DateTime.parse(publishedAt.replaceAll(' GMT', ''));
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
  }

  Article({required this.title, required this.source, required this.publishedAt, required this.summary, this.severity = 'ADVISORY', this.link, this.language, this.thumbnail});

  factory Article.fromMap(Map<String,dynamic> m) {
    return Article(
      title: m['title'] ?? '',
      source: m['source'] ?? m['source.name'] ?? 'Unknown',
      publishedAt: m['publishedAt'] ?? m['pubDate'] ?? '',
      summary: m['description'] ?? m['summary'] ?? m['content'] ?? '',
      severity: m['severity'] ?? 'ADVISORY',
      link: m['link'] ?? m['url'] ?? null,
      language: m['language'] ?? null,
      thumbnail: m['thumbnail'] ?? m['image'] ?? null,
    );
  }

  Map<String,dynamic> toMap() => {
    'title': title,
    'source': source,
    'publishedAt': publishedAt,
    'summary': summary,
    'severity': severity,
    if (link != null) 'link': link,
    if (language != null) 'language': language,
    if (thumbnail != null) 'thumbnail': thumbnail,
  };
}
