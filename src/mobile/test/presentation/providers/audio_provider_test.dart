
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
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

  setUp(() {
    mockAudioPlayer = MockAudioPlayer();
    
    playerStateController = StreamController<PlayerState>.broadcast();
    durationController = StreamController<Duration>.broadcast();
    positionController = StreamController<Duration>.broadcast();

    when(mockAudioPlayer.onPlayerStateChanged).thenAnswer((_) => playerStateController.stream);
    when(mockAudioPlayer.onDurationChanged).thenAnswer((_) => durationController.stream);
    when(mockAudioPlayer.onPositionChanged).thenAnswer((_) => positionController.stream);
    
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
  });
}
