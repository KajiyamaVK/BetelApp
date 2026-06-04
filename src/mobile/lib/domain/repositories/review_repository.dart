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
  /// Activates review for [lessonId] only if no row exists yet (first sync).
  /// Does nothing if the user has already made an explicit choice.
  Future<void> activateReviewIfNew({required int lessonId});
  Future<List<int>> getActiveLessonIds();
  /// Resets all card_progress to bucket=1 and next_review_at=now (dev/test only).
  Future<void> resetAllProgress();
  /// Subtracts 1 day from every next_review_at, making tomorrow's cards due today (dev/test only).
  Future<void> advanceOneDayForTesting();
}
