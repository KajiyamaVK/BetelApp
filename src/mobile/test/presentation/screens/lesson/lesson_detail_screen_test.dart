import 'package:audio_service/audio_service.dart';
import 'package:betelsas/core/audio/betel_audio_handler.dart';
import 'package:betelsas/core/providers.dart';
import 'package:betelsas/data/models/lesson.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:betelsas/presentation/screens/lesson/lesson_detail_screen.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';

import '../../../presentation/providers/audio_provider_test.mocks.dart';

Lesson _lessonWithAudio() => Lesson(
      id: 4,
      title: 'Quem é Deus?',
      localPdfPath: 'betelsas/lessons/4/lesson.pdf',
      localAudioPath: 'betelsas/lessons/4/audio.mp3',
      audioExt: 'mp3',
    );

Lesson _lessonWithoutAudio() => Lesson(
      id: 1,
      title: 'Sem Música',
      localPdfPath: 'betelsas/lessons/1/lesson.pdf',
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
        betelAudioHandlerProvider.overrideWith((ref) => Future.value(_makeStubHandler())),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: child,
      ),
    );

Widget _wrapWithOverride(Widget child, _SpyAudioNotifier notifier) =>
    ProviderScope(
      overrides: [
        audioProvider.overrideWith((_) => notifier),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: child,
      ),
    );

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
}
