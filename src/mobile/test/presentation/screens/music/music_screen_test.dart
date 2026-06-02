import 'package:audio_service/audio_service.dart';
import 'package:betelapp/core/audio/betel_audio_handler.dart';
import 'package:betelapp/data/models/song.dart';
import 'package:betelapp/presentation/providers/audio_provider.dart';
import 'package:betelapp/presentation/screens/music/music_screen.dart';
import 'package:betelapp/presentation/screens/music/music_view_model.dart';
import 'package:betelapp/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';

import 'music_screen_test.mocks.dart';

@GenerateNiceMocks([MockSpec<BetelAudioHandler>()])
final _testSongs = List.generate(
  10,
  (i) => Song(
    id: '${i + 1}',
    title: 'Song ${i + 1}',
    artist: 'Artist',
    audioUrl: 'url_${i + 1}',
    durationIds: 180,
  ),
);

class FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestMusicViewModel extends MusicViewModel {
  _TestMusicViewModel(List<Song> songs) : super(FakeRef() as dynamic) {
    state = AsyncValue.data(songs);
  }

  @override
  Future<void> loadSongs() async {}
}

MockBetelAudioHandler _buildMockHandler() {
  final handler = MockBetelAudioHandler();
  final playbackSubject =
      BehaviorSubject<PlaybackState>.seeded(PlaybackState());
  final mediaItemSubject = BehaviorSubject<MediaItem?>.seeded(null);
  when(handler.playbackState).thenAnswer((_) => playbackSubject);
  when(handler.mediaItem).thenAnswer((_) => mediaItemSubject);
  when(handler.songList).thenReturn([]);
  when(handler.currentIndex).thenReturn(0);
  when(handler.setQueue(any, startIndex: anyNamed('startIndex')))
      .thenAnswer((_) async {});
  when(handler.play()).thenAnswer((_) async {});
  when(handler.pause()).thenAnswer((_) async {});
  when(handler.stop()).thenAnswer((_) async {});
  return handler;
}

Widget _buildScreen({
  required List<Song> songs,
  AudioState overrideAudioState = const AudioState(),
}) {
  final handler = _buildMockHandler();
  final audioNotifier = AudioNotifier(handler: handler)
    ..state = overrideAudioState;

  return ProviderScope(
    overrides: [
      musicViewModelProvider
          .overrideWith((_) => _TestMusicViewModel(songs)),
      audioProvider.overrideWith((_) => audioNotifier),
    ],
    child: const MaterialApp(home: MusicScreen()),
  );
}

void main() {
  group('MusicScreen list bottom padding', () {
    testWidgets(
      'last song card is not obscured by the player widget when scrolled to bottom',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        final playingState = AudioState(
          currentUrl: _testSongs.first.audioUrl,
          isPlaying: true,
          currentTitle: _testSongs.first.title,
          currentArtist: _testSongs.first.artist,
        );

        await tester.pumpWidget(
          _buildScreen(songs: _testSongs, overrideAudioState: playingState),
        );
        await tester.pump();

        // Scroll all the way to the bottom of the list
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
        await tester.pumpAndSettle();

        final lastCard = find.text('Song 9');
        expect(lastCard, findsOneWidget,
            reason: 'last song must be reachable after scrolling to bottom');

        final cardRect = tester.getRect(
          find.ancestor(
            of: lastCard,
            matching: find.byType(Card),
          ).last,
        );
        final playerRect = tester.getRect(find.byType(AudioPlayerWidget));

        expect(
          cardRect.bottom,
          lessThanOrEqualTo(playerRect.top),
          reason:
              'last song card bottom (${cardRect.bottom}) must not overlap player top (${playerRect.top})',
        );
      },
    );

    // Issue #7: when no song is playing, the list should not have a large blank space
    testWidgets(
      'bottom padding is small when no song is playing (player hidden)',
      (tester) async {
        await tester.pumpWidget(_buildScreen(songs: [_testSongs.first]));
        await tester.pump();

        expect(find.byType(AudioPlayerWidget), findsNothing,
            reason: 'AudioPlayerWidget must not be rendered when no song is playing');

        // Inspect the SliverPadding widget directly — it's the contract holder.
        final sliverPadding = tester.widget<SliverPadding>(find.byType(SliverPadding));
        expect(
          sliverPadding.padding.resolve(TextDirection.ltr).bottom,
          lessThan(100),
          reason: 'Bottom padding must be small (~20px) when no song is playing',
        );
      },
    );
  });

  group('MusicScreen song card leading widget', () {
    // Issue #4: leading widget shows lesson number, not a music-note icon
    testWidgets(
      'each song card shows its 1-based position number as leading widget',
      (tester) async {
        final songs = _testSongs.take(3).toList();

        await tester.pumpWidget(_buildScreen(songs: songs));
        await tester.pump();

        for (final song in songs) {
          expect(
            find.text(song.id),
            findsOneWidget,
            reason: 'Card for song ${song.id} must display its lesson number',
          );
        }
      },
    );

    testWidgets(
      'music note icon is not shown on any song card',
      (tester) async {
        await tester.pumpWidget(_buildScreen(songs: _testSongs.take(3).toList()));
        await tester.pump();

        expect(
          find.byIcon(Icons.music_note_rounded),
          findsNothing,
          reason: 'music_note_rounded icon must be replaced by the lesson number',
        );
      },
    );

    testWidgets(
      'graphic_eq icon is shown on the currently playing card instead of the number',
      (tester) async {
        final songs = _testSongs.take(3).toList();
        final playingState = AudioState(
          currentUrl: songs[1].audioUrl,
          isPlaying: true,
          currentTitle: songs[1].title,
          currentArtist: songs[1].artist,
        );

        await tester.pumpWidget(
          _buildScreen(songs: songs, overrideAudioState: playingState),
        );
        await tester.pump();

        expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget,
            reason: 'currently playing card must show graphic_eq icon');
      },
    );
  });
}
