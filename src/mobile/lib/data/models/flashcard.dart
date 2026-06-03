class Flashcard {
  final int id;
  final int lessonId;
  final String question;
  final String answer;

  const Flashcard({
    required this.id,
    required this.lessonId,
    required this.question,
    required this.answer,
  });

  factory Flashcard.fromMap(Map<String, dynamic> map) => Flashcard(
        id: map['question_id'] as int,
        lessonId: map['lesson_id'] as int,
        question: map['question'] as String,
        answer: map['answer'] as String,
      );

  Map<String, dynamic> toMap() => {
        'question_id': id,
        'lesson_id': lessonId,
        'question': question,
        'answer': answer,
      };
}

class CardProgress {
  final int questionId;
  final int lessonId;
  final int bucket;
  final DateTime? lastReviewedAt;
  final DateTime nextReviewAt;
  final String? questionText;
  final String? answerText;

  const CardProgress({
    required this.questionId,
    required this.lessonId,
    required this.bucket,
    this.lastReviewedAt,
    required this.nextReviewAt,
    this.questionText,
    this.answerText,
  });

  factory CardProgress.fromMap(Map<String, dynamic> map) => CardProgress(
        questionId: map['question_id'] as int,
        lessonId: map['lesson_id'] as int,
        bucket: map['bucket'] as int,
        lastReviewedAt: map['last_reviewed_at'] != null
            ? DateTime.parse(map['last_reviewed_at'] as String)
            : null,
        nextReviewAt: map['next_review_at'] != null
            ? DateTime.parse(map['next_review_at'] as String)
            : DateTime.now().add(const Duration(days: 1)),
      );

  // questionText and answerText are display-only join fields — not DB columns, not persisted.
  Map<String, dynamic> toMap() => {
        'question_id': questionId,
        'lesson_id': lessonId,
        'bucket': bucket,
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
        'next_review_at': nextReviewAt.toIso8601String(),
      };
}
