import 'package:betelapp/data/models/flashcard.dart';

abstract class ReviewRepository {
  Future<void> upsertCards(List<Flashcard> flashcards);
  Future<void> recordAnswer({
    required int questionId,
    required bool correct,
    DateTime? answeredAt,
  });
  Future<List<CardProgress>> getDueCards({
    required List<int> lessonIds,
    DateTime? today,
  });
  Future<void> deleteCardsForQuestionIds(List<int> questionIds);
  Future<bool> isReviewActive({required int lessonId});
  Future<void> setReviewActive({required int lessonId, required bool active});
  Future<List<int>> getActiveLessonIds();
}
