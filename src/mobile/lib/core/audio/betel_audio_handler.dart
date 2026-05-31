import 'package:audio_service/audio_service.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:just_audio/just_audio.dart';

class BetelAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _repeatOne = false;

  void setRepeatOne(bool value) => _repeatOne = value;

  BetelAudioHandler({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _initListeners();
  }

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = switch (state.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };

      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        processingState: processingState,
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
      ));

      if (state.processingState == ProcessingState.completed) {
        if (_repeatOne) {
          _player.seek(Duration.zero).then((_) => _player.play());
        }
        // Non-repeat auto-advance is handled by AudioNotifier._onTrackCompleted(),
        // which has full shuffle/repeat context. The handler only manages repeatOne
        // because it needs direct player access without the notifier layer.
      }
    });

    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });

    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  Future<void> setQueue(List<Song> songs, {int startIndex = 0, bool autoPlay = true}) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) return;
    _queue = songs;
    _currentIndex = startIndex;
    await _loadAndPlay(startIndex, autoPlay: autoPlay);
  }

  Future<void> _loadAndPlay(int index, {bool autoPlay = true}) async {
    final song = _queue[index];
    _currentIndex = index;

    mediaItem.add(MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
    ));

    if (autoPlay) {
      // audio_service calls startForeground() only on the false→true transition
      // of playbackState.playing. The Android foreground service must call
      // startForeground() within 5 seconds of being started, or Android kills
      // the process with ANR. Emit playing:true immediately so enterPlayingState()
      // fires before setAudioSource() (which can take several seconds) completes.
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.loading,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
      ));
    }

    try {
      final uri = song.audioUrl.startsWith('http')
          ? Uri.parse(song.audioUrl)
          : Uri.file(song.audioUrl);
      final source = AudioSource.uri(uri);
      await _player.setAudioSource(source, initialPosition: Duration.zero);
      if (autoPlay) await _player.play();
    } catch (e) {
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
      ));
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty || _currentIndex >= _queue.length - 1) return;
    await _loadAndPlay(_currentIndex + 1);
  }

  Future<void> skipToIndex(int index) async {
    if (_queue.isEmpty || index < 0 || index >= _queue.length) return;
    await _loadAndPlay(index);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex <= 0) {
      await _player.seek(Duration.zero);
      return;
    }
    await _loadAndPlay(_currentIndex - 1);
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  int get currentIndex => _currentIndex;
  List<Song> get songList => List.unmodifiable(_queue);
}
