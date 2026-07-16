class ManifestFileEntry {
  final String active;
  final String checksum;

  ManifestFileEntry({required this.active, required this.checksum});

  factory ManifestFileEntry.fromJson(Map<String, dynamic> json) => ManifestFileEntry(
        active: json['active'] as String,
        checksum: json['checksum'] as String,
      );
}

class ManifestAudioEntry extends ManifestFileEntry {
  final String ext;

  ManifestAudioEntry({required super.active, required super.checksum, required this.ext});

  factory ManifestAudioEntry.fromJson(Map<String, dynamic> json) => ManifestAudioEntry(
        active: json['active'] as String,
        checksum: json['checksum'] as String,
        ext: json['ext'] as String,
      );
}

class ManifestQuestion {
  final int id;
  final String question;
  final String answer;

  const ManifestQuestion({required this.id, required this.question, required this.answer});

  factory ManifestQuestion.fromJson(Map<String, dynamic> json) => ManifestQuestion(
        id: json['id'] as int,
        question: json['q'] as String,
        answer: json['a'] as String,
      );
}

class ManifestLesson {
  final int id;
  final String title;
  final ManifestFileEntry pdf;
  final ManifestAudioEntry? audio;
  final List<ManifestQuestion> questions;

  ManifestLesson({
    required this.id,
    required this.title,
    required this.pdf,
    this.audio,
    this.questions = const [],
  });

  factory ManifestLesson.fromJson(Map<String, dynamic> json) => ManifestLesson(
        id: json['id'] as int,
        title: json['title'] as String,
        pdf: ManifestFileEntry.fromJson(json['pdf'] as Map<String, dynamic>),
        audio: json['audio'] != null
            ? ManifestAudioEntry.fromJson(json['audio'] as Map<String, dynamic>)
            : null,
        questions: json['questions'] != null
            ? (json['questions'] as List)
                .map((q) => ManifestQuestion.fromJson(q as Map<String, dynamic>))
                .toList()
            : const [],
      );
}

class ManifestContent {
  final int id;
  final String slug;
  final String title;
  final String type;
  final String? youtubeUrl;
  final String? html;
  // Multi-page TEXT content: each element is one page's HTML.
  // Null for single-page TEXT (uses html) and VIDEO content.
  final List<String>? pages;

  ManifestContent({
    required this.id,
    required this.slug,
    required this.title,
    required this.type,
    this.youtubeUrl,
    this.html,
    this.pages,
  });

  factory ManifestContent.fromJson(Map<String, dynamic> json) => ManifestContent(
        id: json['id'] as int,
        slug: json['slug'] as String,
        title: json['title'] as String,
        type: json['type'] as String,
        youtubeUrl: json['youtubeUrl'] as String?,
        html: json['html'] as String?,
        pages: json['pages'] != null
            ? List<String>.from(json['pages'] as List)
            : null,
      );
}

class ContentManifest {
  final int version;
  final String updatedAt;
  final List<ManifestLesson> lessons;
  final List<ManifestContent> contents;

  ContentManifest({
    required this.version,
    required this.updatedAt,
    required this.lessons,
    this.contents = const [],
  });

  factory ContentManifest.fromJson(Map<String, dynamic> json) => ContentManifest(
        version: json['version'] as int,
        updatedAt: json['updated_at'] as String,
        lessons: (json['lessons'] as List)
            .map((l) => ManifestLesson.fromJson(l as Map<String, dynamic>))
            .toList(),
        // Backward compat: manifests without contents field default to empty list
        contents: json['contents'] != null
            ? (json['contents'] as List)
                .map((c) => ManifestContent.fromJson(c as Map<String, dynamic>))
                .toList()
            : const [],
      );
}
