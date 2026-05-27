import 'package:betelsas/data/models/lesson.dart';
import 'package:betelsas/presentation/screens/lesson/lesson_detail_screen.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget _wrap(Widget child) => ProviderScope(
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
}
