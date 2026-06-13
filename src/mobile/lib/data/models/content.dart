import 'dart:convert';

/// Local model for content stored in SQLite.
/// Read-only — writes only happen in ContentSyncService using raw maps.
class Content {
  final int id;
  final String slug;
  final String title;
  final String type;
  final String? youtubeUrl;
  final String? html;
  // Multi-page TEXT: decoded from the pages_html JSON column in SQLite.
  // Null for single-page TEXT (uses html) and VIDEO content.
  final List<String>? pagesHtml;

  Content({
    required this.id,
    required this.slug,
    required this.title,
    required this.type,
    this.youtubeUrl,
    this.html,
    this.pagesHtml,
  });

  factory Content.fromMap(Map<String, dynamic> map) {
    return Content(
      id: map['id'] as int,
      slug: map['slug'] as String,
      title: map['title'] as String,
      type: map['type'] as String,
      youtubeUrl: map['youtube_url'] as String?,
      html: map['html'] as String?,
      pagesHtml: map['pages_html'] != null
          ? List<String>.from(jsonDecode(map['pages_html'] as String) as List)
          : null,
    );
  }
}
