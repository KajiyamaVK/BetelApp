class ManifestFileEntry {
  final String active;
  final String checksum;
  final List<Map<String, dynamic>> history;

  ManifestFileEntry({required this.active, required this.checksum, required this.history});

  factory ManifestFileEntry.fromJson(Map<String, dynamic> json) => ManifestFileEntry(
        active: json['active'] as String,
        checksum: json['checksum'] as String,
        history: List<Map<String, dynamic>>.from(json['history'] ?? []),
      );
}

class ManifestAudioEntry extends ManifestFileEntry {
  final String ext;

  ManifestAudioEntry({required super.active, required super.checksum, required super.history, required this.ext});

  factory ManifestAudioEntry.fromJson(Map<String, dynamic> json) => ManifestAudioEntry(
        active: json['active'] as String,
        checksum: json['checksum'] as String,
        history: List<Map<String, dynamic>>.from(json['history'] ?? []),
        ext: json['ext'] as String,
      );
}

class ManifestLesson {
  final int id;
  final String title;
  final ManifestFileEntry pdf;
  final ManifestAudioEntry? audio;

  ManifestLesson({required this.id, required this.title, required this.pdf, this.audio});

  factory ManifestLesson.fromJson(Map<String, dynamic> json) => ManifestLesson(
        id: json['id'] as int,
        title: json['title'] as String,
        pdf: ManifestFileEntry.fromJson(json['pdf'] as Map<String, dynamic>),
        audio: json['audio'] != null
            ? ManifestAudioEntry.fromJson(json['audio'] as Map<String, dynamic>)
            : null,
      );
}

class ContentManifest {
  final int version;
  final String updatedAt;
  final List<ManifestLesson> lessons;

  ContentManifest({required this.version, required this.updatedAt, required this.lessons});

  factory ContentManifest.fromJson(Map<String, dynamic> json) => ContentManifest(
        version: json['version'] as int,
        updatedAt: json['updated_at'] as String,
        lessons: (json['lessons'] as List)
            .map((l) => ManifestLesson.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}
