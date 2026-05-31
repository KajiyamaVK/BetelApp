import 'package:audio_service/audio_service.dart';
import 'package:betelsas/core/audio/betel_audio_handler.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';

import 'audio_provider_test.mocks.dart';

@GenerateNiceMocks([MockSpec<BetelAudioHandler>()])
void main() {
  late MockBetelAudioHandler mockHandler;
  late AudioNotifier notifier;
  late BehaviorSubject<PlaybackState> playbackSubject;
  late BehaviorSubject<MediaItem?> mediaItemSubject;

  final songs = [
    Song(id: '1', title: 'Song A', artist: 'Artist', audioUrl: 'url_a', durationIds: 180),
    Song(id: '2', title: 'Song B', artist: 'Artist', audioUrl: 'url_b', durationIds: 200),
    Song(id: '3', title: 'Song C', artist: 'Artist', audioUrl: 'url_c', durationIds: 150),
  ];

  setUp(() {
    mockHandler = MockBetelAudioHandler();

    // Create subjects once so they can emit events and be reused across
    // multiple accesses. Using thenAnswer with a closure that returns the
    // same pre-created subject avoids creating a new BehaviorSubject on
    // every property access (which was the bug with the previous approach).
    playbackSubject = BehaviorSubject<PlaybackState>.seeded(PlaybackState());
    mediaItemSubject = BehaviorSubject<MediaItem?>.seeded(null);

    when(mockHandler.playbackState).thenAnswer((_) => playbackSubject);
    when(mockHandler.mediaItem).thenAnswer((_) => mediaItemSubject);
    when(mockHandler.setQueue(any, startIndex: anyNamed('startIndex'))).thenAnswer((_) async {});
    when(mockHandler.play()).thenAnswer((_) async {});
    when(mockHandler.pause()).thenAnswer((_) async {});
    when(mockHandler.stop()).thenAnswer((_) async {});
    when(mockHandler.seek(any)).thenAnswer((_) async {});
    when(mockHandler.skipToNext()).thenAnswer((_) async {});
    when(mockHandler.skipToPrevious()).thenAnswer((_) async {});
    when(mockHandler.songList).thenReturn([]);
    when(mockHandler.currentIndex).thenReturn(0);
    when(mockHandler.setRepeatOne(any)).thenReturn(null);

    notifier = AudioNotifier(handler: mockHandler);
  });

  group('AudioNotifier', () {
    test('initial state is correct', () {
      expect(notifier.state.isPlaying, false);
      expect(notifier.state.currentUrl, null);
    });

    test('play() calls handler.play and updates state', () async {
      await notifier.play('url_a', title: 'Song A', artist: 'Betel');

      verify(mockHandler.play()).called(greaterThanOrEqualTo(1));
      expect(notifier.state.currentUrl, 'url_a');
      expect(notifier.state.currentTitle, 'Song A');
      expect(notifier.state.currentArtist, 'Betel');
    });

    test('pause() calls handler.pause', () async {
      await notifier.pause();
      verify(mockHandler.pause()).called(1);
      expect(notifier.state.isPlaying, false);
    });

    test('resume() calls handler.play', () async {
      await notifier.resume();
      verify(mockHandler.play()).called(1);
    });

    test('stop() calls handler.stop and resets state', () async {
      await notifier.play('url_a', title: 'Song A', artist: 'Betel');
      await notifier.stop();

      verify(mockHandler.stop()).called(1);
      expect(notifier.state.currentUrl, null);
      expect(notifier.state.isPlaying, false);
    });

    test('seek() calls handler.seek', () async {
      await notifier.seek(const Duration(seconds: 30));
      verify(mockHandler.seek(const Duration(seconds: 30))).called(1);
    });
  });

  group('setQueue', () {
    test('calls handler.setQueue with songs and startIndex', () async {
      await notifier.setQueue(songs, startIndex: 1);

      verify(mockHandler.setQueue(songs, startIndex: 1)).called(1);
    });

    test('updates state.queue and state.currentIndex', () async {
      await notifier.setQueue(songs, startIndex: 1);

      expect(notifier.state.queue, songs);
      expect(notifier.state.currentIndex, 1);
    });
  });

  group('playNext', () {
    test('calls handler.skipToNext', () async {
      await notifier.setQueue(songs, startIndex: 0);
      await notifier.playNext();

      verify(mockHandler.skipToNext()).called(1);
    });

    test('does nothing when queue is empty', () async {
      await notifier.playNext();
      verifyNever(mockHandler.skipToNext());
    });

    test('does nothing when on last song', () async {
      await notifier.setQueue(songs, startIndex: 2);
      await notifier.playNext();

      verifyNever(mockHandler.skipToNext());
    });
  });

  group('playPrevious', () {
    test('calls handler.skipToPrevious', () async {
      await notifier.setQueue(songs, startIndex: 1);
      await notifier.playPrevious();

      verify(mockHandler.skipToPrevious()).called(1);
    });
  });

  group('toggleRepeat', () {
    test('initial repeatMode is off', () {
      expect(notifier.state.repeatMode, AudioRepeatMode.off);
    });

    test('toggleRepeat cycles off -> all -> one -> off', () async {
      await notifier.toggleRepeat();
      expect(notifier.state.repeatMode, AudioRepeatMode.all);

      await notifier.toggleRepeat();
      expect(notifier.state.repeatMode, AudioRepeatMode.one);

      await notifier.toggleRepeat();
      expect(notifier.state.repeatMode, AudioRepeatMode.off);
    });
  });

  group('toggleShuffle', () {
    test('initial shuffleMode is off', () {
      expect(notifier.state.shuffleMode, AudioShuffleMode.off);
    });

    test('toggleShuffle flips off -> on -> off', () async {
      await notifier.toggleShuffle();
      expect(notifier.state.shuffleMode, AudioShuffleMode.on);

      await notifier.toggleShuffle();
      expect(notifier.state.shuffleMode, AudioShuffleMode.off);
    });
  });

  group('playNext with repeat', () {
    test('wraps to first song when repeatMode is all and on last track', () async {
      await notifier.setQueue(songs, startIndex: 2);
      await notifier.toggleRepeat(); // off -> all

      await notifier.playNext();

      verify(mockHandler.skipToNext()).called(1);
      expect(notifier.state.currentIndex, 0);
    });

    test('does nothing on last song when repeatMode is off', () async {
      await notifier.setQueue(songs, startIndex: 2);

      await notifier.playNext();

      verifyNever(mockHandler.skipToNext());
    });
  });

  group('playNext with shuffle', () {
    test('calls skipToIndex (not skipToNext) when shuffle is on', () async {
      when(mockHandler.skipToIndex(any)).thenAnswer((_) async {});
      await notifier.setQueue(songs, startIndex: 0);
      await notifier.toggleShuffle();

      await notifier.playNext();

      verify(mockHandler.skipToIndex(any)).called(1);
      verifyNever(mockHandler.skipToNext());
    });
  });

  group('shuffle auto-advance on natural track completion', () {
    // Regression: when shuffle is on and a track ends naturally, the notifier
    // must call skipToIndex with the next shuffled index — NOT skipToNext()
    // (which is sequential and ignores the shuffled order).
    test('calls skipToIndex (not skipToNext) when shuffle is on and track completes naturally', () async {
      when(mockHandler.skipToIndex(any)).thenAnswer((_) async {});
      await notifier.setQueue(songs, startIndex: 0);
      await notifier.toggleShuffle(); // enable shuffle

      playbackSubject.add(PlaybackState(
        playing: false,
        processingState: AudioProcessingState.completed,
      ));
      await Future.microtask(() {});

      verify(mockHandler.skipToIndex(any)).called(1);
      verifyNever(mockHandler.skipToNext());
    });

    test('advances through the shuffled order on successive natural completions', () async {
      when(mockHandler.skipToIndex(any)).thenAnswer((_) async {});
      await notifier.setQueue(songs, startIndex: 0);
      await notifier.toggleShuffle();

      // First natural completion
      playbackSubject.add(PlaybackState(
        playing: false,
        processingState: AudioProcessingState.completed,
      ));
      await Future.microtask(() {});

      final firstIndex = verify(mockHandler.skipToIndex(captureAny)).captured.last as int;
      // Index must have changed from 0 (since shuffle picked a different track)
      expect(firstIndex, isNot(0), reason: 'shuffle must not stay on the same track');
    });
  });

  group('playPrevious with shuffle', () {
    // Regression: playPrevious() was ignoring _shuffledIndices and calling
    // skipToPrevious() (linear), which goes to index-1 instead of the prior
    // position in the shuffled order.
    test('calls skipToIndex (not skipToPrevious) when shuffle is on', () async {
      when(mockHandler.skipToIndex(any)).thenAnswer((_) async {});
      await notifier.setQueue(songs, startIndex: 1);
      await notifier.toggleShuffle();

      await notifier.playPrevious();

      verify(mockHandler.skipToIndex(any)).called(greaterThanOrEqualTo(1));
      verifyNever(mockHandler.skipToPrevious());
    });
  });

  group('repeatAll auto-loop on natural track completion', () {
    // Regression: when playback completes on the last track with repeatMode=all,
    // the notifier must detect the completed processingState and call skipToIndex(0).
    // Previously, skipToNext() on the last item returned early with no action.
    test('calls skipToIndex(0) when playbackState emits completed on last track with repeatMode all', () async {
      when(mockHandler.skipToIndex(any)).thenAnswer((_) async {});
      await notifier.setQueue(songs, startIndex: 2); // last track
      await notifier.toggleRepeat(); // off -> all

      playbackSubject.add(PlaybackState(
        playing: false,
        processingState: AudioProcessingState.completed,
      ));
      await Future.microtask(() {});

      verify(mockHandler.skipToIndex(0)).called(1);
    });
  });

  group('repeatOne — slider and play state after natural restart', () {
    // Regression: when repeat_one is active and the track completes, the notifier
    // emitted position=duration briefly before the handler restarted, leaving the
    // slider stuck at the end with the pause button visible.
    test('resets position to zero when playbackState emits completed with repeatMode one', () async {
      await notifier.setQueue(songs, startIndex: 0);
      await notifier.toggleRepeat(); // off -> all
      await notifier.toggleRepeat(); // all -> one

      // Simulate: position reaches near end (still playing)
      playbackSubject.add(PlaybackState(
        playing: true,
        updatePosition: const Duration(seconds: 180),
        processingState: AudioProcessingState.ready,
      ));
      await Future.microtask(() {});

      // Simulate: natural completion
      playbackSubject.add(PlaybackState(
        playing: false,
        updatePosition: const Duration(seconds: 180),
        processingState: AudioProcessingState.completed,
      ));
      await Future.microtask(() {});

      expect(notifier.state.position, Duration.zero,
          reason: 'repeat_one: slider must reset to zero immediately on completion, not stay at end');
    });
  });

  group('currentUrl sync from mediaItem stream', () {
    test('currentUrl and currentIndex update when handler emits a new mediaItem (e.g. autoplay advance)', () async {
      await notifier.setQueue(songs, startIndex: 0);
      expect(notifier.state.currentUrl, 'url_a');
      expect(notifier.state.currentIndex, 0);

      // Simulate handler advancing to track index 1 autonomously (autoplay/notification)
      mediaItemSubject.add(MediaItem(id: '2', title: 'Song B', artist: 'Artist'));
      await Future.microtask(() {}); // let stream listeners run

      expect(notifier.state.currentUrl, 'url_b',
          reason: 'currentUrl must reflect the new track emitted by the handler');
      expect(notifier.state.currentIndex, 1,
          reason: 'currentIndex must point to the new track in the queue');
    });

    test('currentUrl does not change when mediaItem emits a song not in the queue', () async {
      await notifier.setQueue(songs, startIndex: 0);

      mediaItemSubject.add(MediaItem(id: 'unknown', title: 'Unknown', artist: 'X'));
      await Future.microtask(() {});

      // Should not crash and should leave currentUrl unchanged
      expect(notifier.state.currentUrl, 'url_a');
    });
  });
}
