import 'package:audio_service/audio_service.dart';
import 'package:betelapp/core/audio/betel_audio_handler.dart';
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/core/providers.dart';
import 'package:betelapp/data/models/flashcard.dart';
import 'package:betelapp/data/models/lesson.dart';
import 'package:betelapp/data/repositories/review_repository_impl.dart';
import 'package:betelapp/presentation/providers/audio_provider.dart';
import 'package:betelapp/presentation/screens/lesson/lesson_detail_screen.dart';
import 'package:betelapp/presentation/screens/reviews/reviews_view_model.dart';
import 'package:betelapp/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';

import '../../../presentation/providers/audio_provider_test.mocks.dart';

// ---------------------------------------------------------------------------
// In-memory stub — no SQLite, safe to use in widget (FakeAsync) tests
// ---------------------------------------------------------------------------

class _StubReviewRepo extends ReviewRepositoryImpl {
  bool _active = false;

  // DatabaseHelper() returns the singleton but never accesses the database
  // because all database-calling methods are overridden below.
  _StubReviewRepo() : super(DatabaseHelper());

  void seedActive(bool value) => _active = value;

  @override
  Future<void> upsertCards(List<Flashcard> flashcards) async {}

  @override
  Future<void> recordAnswer({
    required int questionId,
    required bool correct,
    DateTime? answeredAt,
  }) async {}

  @override
  Future<List<CardProgress>> getDueCards({
    required List<int> lessonIds,
    DateTime? today,
  }) async =>
      [];

  @override
  Future<void> deleteCardsForQuestionIds(List<int> questionIds) async {}

  @override
  Future<bool> isReviewActive({required int lessonId}) async => _active;

  @override
  Future<void> setReviewActive({
    required int lessonId,
    required bool active,
  }) async {
    _active = active;
  }

  @override
  Future<List<int>> getActiveLessonIds() async => [];
}

// ---------------------------------------------------------------------------
// Widget test helpers
// ---------------------------------------------------------------------------

Lesson _lessonWithAudio() => Lesson(
      id: 4,
      title: 'Quem é Deus?',
      localPdfPath: 'betelapp/lessons/4/lesson.pdf',
      localAudioPath: 'betelapp/lessons/4/audio.mp3',
      audioExt: 'mp3',
    );

Lesson _lessonWithoutAudio() => Lesson(
      id: 1,
      title: 'Sem Música',
      localPdfPath: 'betelapp/lessons/1/lesson.pdf',
    );

BetelAudioHandler _makeStubHandler() {
  final handler = MockBetelAudioHandler();
  when(handler.playbackState).thenAnswer((_) => BehaviorSubject.seeded(PlaybackState()));
  when(handler.mediaItem).thenAnswer((_) => BehaviorSubject.seeded(null));
  when(handler.play()).thenAnswer((_) async {});
  when(handler.pause()).thenAnswer((_) async {});
  when(handler.stop()).thenAnswer((_) async {});
  when(handler.seek(any)).thenAnswer((_) async {});
  when(handler.skipToNext()).thenAnswer((_) async {});
  when(handler.skipToPrevious()).thenAnswer((_) async {});
  when(handler.setQueue(any, startIndex: anyNamed('startIndex'))).thenAnswer((_) async {});
  when(handler.songList).thenReturn([]);
  when(handler.currentIndex).thenReturn(0);
  return handler;
}

// Spy notifier that records whether stop() was called.
class _SpyAudioNotifier extends AudioNotifier {
  bool stopCalled = false;

  _SpyAudioNotifier() : super(handler: _makeStubHandler());

  @override
  Future<void> stop() async {
    stopCalled = true;
    await super.stop();
  }
}

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        betelAudioHandlerProvider.overrideWithValue(_makeStubHandler()),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: child,
      ),
    );

Widget _wrapWithReview(Widget child, _StubReviewRepo repo) {
  final vm = ReviewViewModel(repo);
  return ProviderScope(
    overrides: [
      betelAudioHandlerProvider.overrideWithValue(_makeStubHandler()),
      reviewRepositoryProvider.overrideWithValue(repo),
      reviewViewModelProvider.overrideWith((_) => vm),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: false),
      home: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LessonDetailScreen — floating player', () {
    testWidgets('shows AudioPlayerWidget when lesson has audio', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithAudio())));
      await tester.pump();

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('does not show AudioPlayerWidget when lesson has no audio', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithoutAudio())));
      await tester.pump();

      expect(find.byType(AudioPlayerWidget), findsNothing);
    });

    testWidgets('player does not show restart button in lesson context', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithAudio())));
      await tester.pump();

      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
    });
  });

  // UX: a loading overlay must be visible until the PDF viewer signals it is ready.
  // This covers the gap where localPdfPath is set but PdfViewer is still parsing.
  group('LessonDetailScreen — loading state', () {
    testWidgets('shows loading overlay when localPdfPath is set but PDF is not yet ready', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithAudio())));
      await tester.pump(); // localPdfPath resolves (or stays null in test env — either way)

      // The loading overlay must be visible until onViewerReady fires
      expect(find.byKey(const Key('lesson-pdf-loading')), findsOneWidget);
    });
  });

  // Regression: when the user backs out of a lesson, audio must stop so that
  // the Music tab queue-based navigation remains functional.
  group('LessonDetailScreen — audio lifecycle', () {
    testWidgets('audio stops when lesson screen is popped', (tester) async {
      final spy = _SpyAudioNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [audioProvider.overrideWith((_) => spy)],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonDetailScreen(lesson: _lessonWithAudio()),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Navigate to lesson
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LessonDetailScreen), findsOneWidget);
      expect(spy.stopCalled, isFalse);

      // Pop back
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LessonDetailScreen), findsNothing);
      expect(spy.stopCalled, isTrue,
          reason: 'Audio must stop when the lesson screen is dismissed');
    });
  });

  group('LessonDetailScreen — review toggle button', () {
    testWidgets(
        'review toggle icon is not shown when lesson has no questions',
        (tester) async {
      final repo = _StubReviewRepo();
      final lesson = Lesson(
        id: 1,
        title: 'No Q&A',
        localPdfPath: 'betelapp/lessons/1/lesson.pdf',
        questionCount: 0,
      );
      await tester.pumpWidget(_wrapWithReview(LessonDetailScreen(lesson: lesson), repo));
      await tester.pump();

      expect(find.byIcon(Icons.style_rounded), findsNothing);
    });

    testWidgets(
        'review toggle icon is shown when lesson has questions and is initially inactive',
        (tester) async {
      final repo = _StubReviewRepo();
      final lesson = Lesson(
        id: 2,
        title: 'With Q&A',
        localPdfPath: 'betelapp/lessons/2/lesson.pdf',
        questionCount: 3,
      );
      await tester.pumpWidget(_wrapWithReview(LessonDetailScreen(lesson: lesson), repo));
      await tester.pump(); // initial build
      await tester.pump(const Duration(milliseconds: 100)); // async _loadState

      expect(find.byIcon(Icons.style_rounded), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.style_rounded));
      expect(icon.color, Colors.white54,
          reason: 'icon should be dimmed when review is inactive');
    });

    testWidgets(
        'tapping review toggle activates review and repo state is updated',
        (tester) async {
      final repo = _StubReviewRepo();
      final lesson = Lesson(
        id: 3,
        title: 'Toggleable',
        localPdfPath: 'betelapp/lessons/3/lesson.pdf',
        questionCount: 2,
      );
      await tester.pumpWidget(_wrapWithReview(LessonDetailScreen(lesson: lesson), repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // _loadState completes

      // Initial state: inactive (white54)
      expect(
        tester.widget<Icon>(find.byIcon(Icons.style_rounded)).color,
        Colors.white54,
      );

      // Tap to activate
      await tester.tap(find.byIcon(Icons.style_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // _toggle completes

      // Stub should now report active = true
      expect(
        await repo.isReviewActive(lessonId: lesson.id),
        isTrue,
        reason: 'stub repo should reflect the toggled state',
      );
    });
  });
}
