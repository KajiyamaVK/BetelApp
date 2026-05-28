import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:betelsas/core/audio/betel_audio_handler.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'betel_audio_handler_test.mocks.dart';

@GenerateNiceMocks([MockSpec<AudioPlayer>()])
void main() {
  late MockAudioPlayer mockPlayer;
  late BetelAudioHandler handler;
  late StreamController<PlayerState> playerStateController;
  late StreamController<Duration?> durationController;
  late StreamController<Duration> positionController;
  late StreamController<ProcessingState> processingStateController;

  final songs = [
    Song(id: '1', title: 'Song A', artist: 'Betel', audioUrl: '/audio/a.mp3', durationIds: 180),
    Song(id: '2', title: 'Song B', artist: 'Betel', audioUrl: '/audio/b.mp3', durationIds: 200),
    Song(id: '3', title: 'Song C', artist: 'Betel', audioUrl: '/audio/c.mp3', durationIds: 150),
  ];

  setUp(() {
    mockPlayer = MockAudioPlayer();
    playerStateController = StreamController<PlayerState>.broadcast();
    durationController = StreamController<Duration?>.broadcast();
    positionController = StreamController<Duration>.broadcast();
    processingStateController = StreamController<ProcessingState>.broadcast();

    when(mockPlayer.playerStateStream).thenAnswer((_) => playerStateController.stream);
    when(mockPlayer.durationStream).thenAnswer((_) => durationController.stream);
    when(mockPlayer.positionStream).thenAnswer((_) => positionController.stream);
    when(mockPlayer.processingStateStream).thenAnswer((_) => processingStateController.stream);
    when(mockPlayer.setAudioSource(any, initialPosition: anyNamed('initialPosition')))
        .thenAnswer((_) async => null);
    when(mockPlayer.play()).thenAnswer((_) async {});
    when(mockPlayer.pause()).thenAnswer((_) async {});
    when(mockPlayer.stop()).thenAnswer((_) async {});
    when(mockPlayer.seek(any)).thenAnswer((_) async {});
    when(mockPlayer.dispose()).thenAnswer((_) async {});

    handler = BetelAudioHandler(player: mockPlayer);
  });

  tearDown(() {
    playerStateController.close();
    durationController.close();
    positionController.close();
    processingStateController.close();
  });

  group('BetelAudioHandler', () {
    test('initial mediaItem is null', () {
      expect(handler.mediaItem.value, isNull);
    });

    test('setQueue loads songs and updates mediaItem for first song', () async {
      await handler.setQueue(songs, startIndex: 0);

      expect(handler.mediaItem.value?.title, 'Song A');
      expect(handler.mediaItem.value?.artist, 'Betel');
      verify(mockPlayer.setAudioSource(any, initialPosition: anyNamed('initialPosition'))).called(1);
    });

    test('setQueue starts playing at given startIndex', () async {
      await handler.setQueue(songs, startIndex: 1);

      expect(handler.mediaItem.value?.title, 'Song B');
    });

    test('play() calls player.play()', () async {
      await handler.setQueue(songs, startIndex: 0);
      await handler.play();

      verify(mockPlayer.play()).called(greaterThanOrEqualTo(1));
    });

    test('pause() calls player.pause()', () async {
      await handler.pause();
      verify(mockPlayer.pause()).called(1);
    });

    test('seek() calls player.seek()', () async {
      await handler.seek(const Duration(seconds: 30));
      verify(mockPlayer.seek(const Duration(seconds: 30))).called(1);
    });

    test('skipToNext() advances to next song', () async {
      await handler.setQueue(songs, startIndex: 0);
      await handler.skipToNext();

      expect(handler.mediaItem.value?.title, 'Song B');
      verify(mockPlayer.setAudioSource(any, initialPosition: anyNamed('initialPosition')))
          .called(greaterThanOrEqualTo(2));
    });

    test('skipToNext() does nothing on last song', () async {
      await handler.setQueue(songs, startIndex: 2);
      clearInteractions(mockPlayer);

      await handler.skipToNext();

      expect(handler.mediaItem.value?.title, 'Song C');
      verifyNever(mockPlayer.setAudioSource(any, initialPosition: anyNamed('initialPosition')));
    });

    test('skipToPrevious() goes to previous song when index > 0', () async {
      await handler.setQueue(songs, startIndex: 1);
      clearInteractions(mockPlayer);

      await handler.skipToPrevious();

      expect(handler.mediaItem.value?.title, 'Song A');
    });

    test('skipToPrevious() seeks to zero on first song', () async {
      await handler.setQueue(songs, startIndex: 0);
      clearInteractions(mockPlayer);

      await handler.skipToPrevious();

      verify(mockPlayer.seek(Duration.zero)).called(1);
      verifyNever(mockPlayer.setAudioSource(any, initialPosition: anyNamed('initialPosition')));
    });

    test('stop() calls player.stop()', () async {
      await handler.stop();
      verify(mockPlayer.stop()).called(1);
    });

    test('onTaskRemoved() calls stop()', () async {
      await handler.onTaskRemoved();
      verify(mockPlayer.stop()).called(1);
    });

    test('auto-advances to next song when processingState completes', () async {
      await handler.setQueue(songs, startIndex: 0);
      clearInteractions(mockPlayer);

      // Simulate the player completing the current track
      playerStateController.add(PlayerState(false, ProcessingState.completed));
      await Future.delayed(Duration.zero);

      expect(handler.mediaItem.value?.title, 'Song B');
      verify(mockPlayer.setAudioSource(any, initialPosition: anyNamed('initialPosition'))).called(1);
    });

    test('emits playing:true loading state before setAudioSource to prevent ANR', () async {
      // Regression: audio_service only calls startForeground() on the false→true
      // transition of playbackState.playing. Android kills the foreground service
      // with ANR if startForeground() is not called within 5 seconds of service
      // start. We must emit playing:true before setAudioSource() (which can be slow).
      final states = <PlaybackState>[];
      handler.playbackState.listen(states.add);

      await handler.setQueue(songs, startIndex: 0, autoPlay: true);

      expect(
        states.any((s) => s.processingState == AudioProcessingState.loading && s.playing),
        isTrue,
        reason: 'A loading state with playing:true must be emitted before setAudioSource() '
            'to trigger enterPlayingState() and startForeground() in time',
      );
    });

    test('does not emit playing:true when autoPlay is false (load-only)', () async {
      // When load() pre-loads audio without playing, no playing:true state should
      // be emitted — the foreground service must not start until the user taps Play.
      final states = <PlaybackState>[];
      handler.playbackState.listen(states.add);

      await handler.setQueue(songs, startIndex: 0, autoPlay: false);

      expect(
        states.any((s) => s.playing),
        isFalse,
        reason: 'autoPlay:false must not emit playing:true or start the foreground service',
      );
      verifyNever(mockPlayer.play());
    });

    test('emits idle playbackState when setAudioSource throws to avoid service limbo', () async {
      // Regression: if audio source fails to load, the foreground service must not
      // be left in limbo (which causes ANR). We must emit an idle stopped state.
      when(mockPlayer.setAudioSource(any, initialPosition: anyNamed('initialPosition')))
          .thenThrow(Exception('file not found'));

      await handler.setQueue(songs, startIndex: 0, autoPlay: true);

      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
    });
  });
}
