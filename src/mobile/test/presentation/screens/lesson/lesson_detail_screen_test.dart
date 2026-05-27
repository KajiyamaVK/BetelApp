import 'package:betelsas/data/models/lesson.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:betelsas/presentation/screens/lesson/lesson_detail_screen.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Lesson _lessonWithSong() => Lesson(
      id: 4,
      title: 'Quem é Deus?',
      content: 'Conteúdo',
      scriptureReference: 'João 3:16',
      imageUrl: '',
      pdfUrl: null,
      flashcards: [],
      song: Song(
        id: 'song_4',
        title: 'Quem é Deus?',
        artist: 'Betel Kids',
        audioUrl: 'assets/audio/lesson_4.mp3',
        durationIds: 120,
      ),
    );

Lesson _lessonWithoutSong() => Lesson(
      id: 1,
      title: 'Sem Música',
      content: 'Conteúdo',
      scriptureReference: 'João 1:1',
      imageUrl: '',
      pdfUrl: null,
      flashcards: [],
      song: null,
    );

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: child,
      ),
    );

void main() {
  group('LessonDetailScreen — floating player', () {
    testWidgets('shows AudioPlayerWidget when lesson has a song', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithSong())));
      await tester.pump();

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
    });

    testWidgets('does not show AudioPlayerWidget when lesson has no song', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithoutSong())));
      await tester.pump();

      expect(find.byType(AudioPlayerWidget), findsNothing);
    });

    testWidgets('player does not show restart button in lesson context', (tester) async {
      await tester.pumpWidget(_wrap(LessonDetailScreen(lesson: _lessonWithSong())));
      await tester.pump();

      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
    });
  });
}
