class Lesson {
  final int id;
  final String title;
  final String localPdfPath;
  final String? localAudioPath;
  final String? audioExt;
  final int questionCount;

  Lesson({
    required this.id,
    required this.title,
    required this.localPdfPath,
    this.localAudioPath,
    this.audioExt,
    this.questionCount = 0,
  });

  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'] as int,
      title: map['title'] as String,
      localPdfPath: map['pdf_local_path'] as String,
      localAudioPath: map['audio_local_path'] as String?,
      audioExt: map['audio_ext'] as String?,
      questionCount: (map['question_count'] as int?) ?? 0,
    );
  }
}
