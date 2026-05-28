
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'audio_provider_test.mocks.dart';

@GenerateNiceMocks([MockSpec<AudioPlayer>()])
void main() {
  late MockAudioPlayer mockAudioPlayer;
  late AudioNotifier notifier;
  late StreamController<PlayerState> playerStateController;
  late StreamController<Duration> durationController;
  late StreamController<Duration> positionController;
  late StreamController<void> playerCompleteController;

  setUp(() {
    mockAudioPlayer = MockAudioPlayer();

    playerStateController = StreamController<PlayerState>.broadcast();
    durationController = StreamController<Duration>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    playerCompleteController = StreamController<void>.broadcast();

    when(mockAudioPlayer.onPlayerStateChanged).thenAnswer((_) => playerStateController.stream);
    when(mockAudioPlayer.onDurationChanged).thenAnswer((_) => durationController.stream);
    when(mockAudioPlayer.onPositionChanged).thenAnswer((_) => positionController.stream);
    when(mockAudioPlayer.onPlayerComplete).thenAnswer((_) => playerCompleteController.stream);

    // We also need to mock setSource, play, pause etc to return Futures
    when(mockAudioPlayer.setSource(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.resume()).thenAnswer((_) async {});
    when(mockAudioPlayer.pause()).thenAnswer((_) async {});
    when(mockAudioPlayer.stop()).thenAnswer((_) async {});
    when(mockAudioPlayer.seek(any)).thenAnswer((_) async {});

    notifier = AudioNotifier(player: mockAudioPlayer);
  });

  tearDown(() {
    playerStateController.close();
    durationController.close();
    positionController.close();
    playerCompleteController.close();
  });

  group('AudioNotifier', () {
    test('initial state is correct', () {
      expect(notifier.state.isPlaying, false);
      expect(notifier.state.currentUrl, null);
    });

    test('play() updates state and calls player.play', () async {
      const url = 'https://example.com/song.mp3';
      const title = 'Test Song';
      const artist = 'Test Artist';

      await notifier.play(url, title: title, artist: artist);
      // isPlaying is driven by onPlayerStateChanged listener, not set directly by play()
      playerStateController.add(PlayerState.playing);
      await Future.delayed(Duration.zero);

      expect(notifier.state.isPlaying, true);
      expect(notifier.state.currentUrl, url);
      expect(notifier.state.currentTitle, title);
      expect(notifier.state.currentArtist, artist);

      verify(mockAudioPlayer.setSource(any)).called(1);
      verify(mockAudioPlayer.resume()).called(1);
    });

    test('pause() updates state and calls player.pause', () async {
      // Setup initial playing state
      // We can't easily set initial state without a setter/method or creating a new notifier with initial state,
      // but we can call play first.
      await notifier.play('url', title: 't', artist: 'a');
      
      await notifier.pause();

      expect(notifier.state.isPlaying, false);
      verify(mockAudioPlayer.pause()).called(1);
    });

    test('resume() updates state and calls player.resume', () async {
      await notifier.play('url', title: 't', artist: 'a');
      await notifier.pause();

      await notifier.resume();

      expect(notifier.state.isPlaying, true);
      verify(mockAudioPlayer.resume()).called(2); // Once for play, once for resume
    });

    test('load() sets metadata and source without playing', () async {
      const url = 'assets/audio/lesson_4.mp3';
      const title = 'Quem é Deus?';
      const artist = 'Betel Kids';

      await notifier.load(url, title: title, artist: artist);

      expect(notifier.state.isPlaying, false);
      expect(notifier.state.currentUrl, url);
      expect(notifier.state.currentTitle, title);
      expect(notifier.state.currentArtist, artist);
      expect(notifier.state.position, Duration.zero);

      verify(mockAudioPlayer.setSource(any)).called(1);
      verifyNever(mockAudioPlayer.resume());
    });

    // Regression: duration showed 00:00 because state was written after
    // setSource(), overwriting the real duration emitted by onDurationChanged.
    test('load() preserves duration emitted by onDurationChanged during setSource', () async {
      const realDuration = Duration(minutes: 3, seconds: 45);

      // Emit duration from the listener as setSource would trigger on a real player
      when(mockAudioPlayer.setSource(any)).thenAnswer((_) async {
        durationController.add(realDuration);
      });

      await notifier.load('assets/audio/lesson.mp3', title: 'Test', artist: 'Betel');

      expect(
        notifier.state.duration,
        realDuration,
        reason: 'duration emitted by onDurationChanged must not be overwritten by load()',
      );
    });
  });

  group('setQueue', () {
    test('stores queue in state and sets currentIndex to startIndex', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
        Song(id: '3', title: 'Song C', artist: 'Artist', audioUrl: 'url_c', durationIds: 150),
      ];

      await notifier.setQueue(songs, startIndex: 1);

      expect(notifier.state.queue, songs);
      expect(notifier.state.currentIndex, 1);
    });

    test('plays the song at startIndex', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      ];

      await notifier.setQueue(songs, startIndex: 0);

      expect(notifier.state.currentUrl, 'url_a');
      expect(notifier.state.currentTitle, 'Song A');
    });

    test('defaults to startIndex 0 when not provided', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      ];

      await notifier.setQueue(songs);

      expect(notifier.state.currentIndex, 0);
      expect(notifier.state.currentUrl, 'url_a');
    });
  });

  group('playNext', () {
    test('advances to the next song in the queue', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      ];
      await notifier.setQueue(songs, startIndex: 0);
      clearInteractions(mockAudioPlayer);

      await notifier.playNext();

      expect(notifier.state.currentIndex, 1);
      expect(notifier.state.currentUrl, 'url_b');
      verify(mockAudioPlayer.setSource(any)).called(1);
    });

    test('does nothing when already on the last song', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      ];
      await notifier.setQueue(songs, startIndex: 1);
      clearInteractions(mockAudioPlayer);

      await notifier.playNext();

      expect(notifier.state.currentIndex, 1);
      verifyNever(mockAudioPlayer.setSource(any));
      verifyNever(mockAudioPlayer.resume());
    });

    test('does nothing when queue is empty', () async {
      await notifier.playNext();

      verifyNever(mockAudioPlayer.setSource(any));
    });
  });

  group('auto-play on complete', () {
    test('calls playNext when onPlayerComplete fires', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      ];
      await notifier.setQueue(songs, startIndex: 0);
      clearInteractions(mockAudioPlayer);

      playerCompleteController.add(null);
      await Future.delayed(Duration.zero);

      expect(notifier.state.currentIndex, 1);
      expect(notifier.state.currentUrl, 'url_b');
    });

    test('stops on last song when onPlayerComplete fires', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      ];
      await notifier.setQueue(songs, startIndex: 1);
      clearInteractions(mockAudioPlayer);

      playerCompleteController.add(null);
      await Future.delayed(Duration.zero);

      expect(notifier.state.currentIndex, 1);
      verifyNever(mockAudioPlayer.setSource(any));
    });
  });

  group('playPrevious', () {
    test('seeks to zero when position >= 2s', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      ];
      await notifier.setQueue(songs, startIndex: 1);
      positionController.add(const Duration(seconds: 3));
      await Future.delayed(Duration.zero);
      clearInteractions(mockAudioPlayer);

      await notifier.playPrevious();

      verify(mockAudioPlayer.seek(Duration.zero)).called(1);
      verifyNever(mockAudioPlayer.setSource(any));
      expect(notifier.state.currentIndex, 1); // index unchanged
    });

    test('goes to previous song when position < 2s and not first song', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      ];
      await notifier.setQueue(songs, startIndex: 1);
      positionController.add(const Duration(seconds: 1));
      await Future.delayed(Duration.zero);
      clearInteractions(mockAudioPlayer);

      await notifier.playPrevious();

      expect(notifier.state.currentIndex, 0);
      expect(notifier.state.currentUrl, 'url_a');
      verify(mockAudioPlayer.setSource(any)).called(1);
    });

    test('seeks to zero when position < 2s and is first song', () async {
      final songs = [
        Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
        Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
      ];
      await notifier.setQueue(songs, startIndex: 0);
      positionController.add(const Duration(seconds: 1));
      await Future.delayed(Duration.zero);
      clearInteractions(mockAudioPlayer);

      await notifier.playPrevious();

      verify(mockAudioPlayer.seek(Duration.zero)).called(1);
      verifyNever(mockAudioPlayer.setSource(any));
      expect(notifier.state.currentIndex, 0);
    });

    test('seeks to zero when position < 2s and queue is empty', () async {
      positionController.add(const Duration(seconds: 1));
      await Future.delayed(Duration.zero);
      clearInteractions(mockAudioPlayer);

      await notifier.playPrevious();

      verify(mockAudioPlayer.seek(Duration.zero)).called(1);
      verifyNever(mockAudioPlayer.setSource(any));
    });
  });
}
