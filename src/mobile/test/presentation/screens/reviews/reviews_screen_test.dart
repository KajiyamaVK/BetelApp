import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/core/providers.dart';
import 'package:betelapp/data/models/flashcard.dart';
import 'package:betelapp/presentation/screens/reviews/reviews_screen.dart';
import 'package:betelapp/presentation/screens/reviews/reviews_view_model.dart';
import 'package:betelapp/presentation/screens/reviews/review_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betelapp/data/repositories/review_repository_impl.dart';

// ---------------------------------------------------------------------------
// Stub repo — controlled in-memory state, no SQLite
// ---------------------------------------------------------------------------

class _StubReviewRepo extends ReviewRepositoryImpl {
  List<CardProgress> _dueCards;

  _StubReviewRepo({required List<CardProgress> initialDue})
      : _dueCards = initialDue,
        super(DatabaseHelper());

  void setDueCards(List<CardProgress> cards) => _dueCards = cards;

  @override
  Future<List<int>> getActiveLessonIds() async => [1];

  @override
  Future<List<CardProgress>> getDueCards({
    required List<int> lessonIds,
    DateTime? today,
  }) async =>
      _dueCards;

  @override
  Future<bool> isReviewActive({required int lessonId}) async => true;

  @override
  Future<void> setReviewActive({
    required int lessonId,
    required bool active,
  }) async {}

  @override
  Future<void> activateReviewIfNew({required int lessonId}) async {}

  @override
  Future<void> upsertCards(List<Flashcard> flashcards) async {}

  @override
  Future<void> recordAnswer({
    required int questionId,
    required bool correct,
    DateTime? answeredAt,
  }) async {}

  @override
  Future<void> deleteCardsForQuestionIds(List<int> questionIds) async {}

  @override
  Future<void> resetAllProgress() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CardProgress _card(int id) => CardProgress(
      questionId: id,
      lessonId: 1,
      bucket: 1,
      nextReviewAt: DateTime(2000),
      questionText: 'Q$id?',
      answerText: 'A$id.',
    );

Widget _buildApp(_StubReviewRepo repo) {
  final vm = ReviewViewModel(repo);
  return ProviderScope(
    overrides: [
      reviewRepositoryProvider.overrideWithValue(repo),
      reviewViewModelProvider.overrideWith((_) => vm),
    ],
    child: const MaterialApp(home: ReviewsScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReviewsScreen', () {
    testWidgets(
        'counter refreshes after navigating back from ReviewSessionScreen mid-session',
        (tester) async {
      // Start with 3 due cards
      final repo = _StubReviewRepo(
        initialDue: [_card(1), _card(2), _card(3)],
      );
      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // Counter shows 3 on the ReviewsScreen banner
      expect(find.text('3 perguntas para revisar hoje'), findsOneWidget);

      // Tap "Começar Sessão" to navigate to ReviewSessionScreen
      await tester.tap(find.text('Começar Sessão'));
      await tester.pumpAndSettle();

      // Simulate user answering one card (marking "errei"), reducing due to 2.
      // We update the stub BEFORE popping so loadState() picks it up.
      repo.setDueCards([_card(2), _card(3)]);

      // User presses back without finishing the session
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      // Counter must now reflect the updated due count
      expect(
        find.text('2 perguntas para revisar hoje'),
        findsOneWidget,
        reason:
            'ReviewsScreen must reload after ReviewSessionScreen is popped '
            'even if the session was not completed',
      );
    });
  });
}
