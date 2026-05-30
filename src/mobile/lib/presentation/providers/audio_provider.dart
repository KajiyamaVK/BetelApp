import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:betelsas/core/audio/betel_audio_handler.dart';
import 'package:betelsas/core/providers.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AudioRepeatMode { off, all, one }

enum AudioShuffleMode { off, on }

class AudioState {
  final bool isPlaying;
  final String? currentUrl;
  final String? currentTitle;
  final String? currentArtist;
  final Duration duration;
  final Duration position;
  final List<Song> queue;
  final int? currentIndex;
  final AudioRepeatMode repeatMode;
  final AudioShuffleMode shuffleMode;

  const AudioState({
    this.isPlaying = false,
    this.currentUrl,
    this.currentTitle,
    this.currentArtist,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.queue = const [],
    this.currentIndex,
    this.repeatMode = AudioRepeatMode.off,
    this.shuffleMode = AudioShuffleMode.off,
  });

  AudioState copyWith({
    bool? isPlaying,
    String? currentUrl,
    String? currentTitle,
    String? currentArtist,
    Duration? duration,
    Duration? position,
    List<Song>? queue,
    int? currentIndex,
    AudioRepeatMode? repeatMode,
    AudioShuffleMode? shuffleMode,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentUrl: currentUrl ?? this.currentUrl,
      currentTitle: currentTitle ?? this.currentTitle,
      currentArtist: currentArtist ?? this.currentArtist,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleMode: shuffleMode ?? this.shuffleMode,
    );
  }
}

final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  final handler = ref.watch(betelAudioHandlerProvider);
  return AudioNotifier(handler: handler);
});

class AudioNotifier extends StateNotifier<AudioState> {
  final BetelAudioHandler _handler;
  List<int> _shuffledIndices = [];

  StreamSubscription<PlaybackState>? _playbackSub;
  StreamSubscription<MediaItem?>? _mediaItemSub;

  AudioNotifier({required BetelAudioHandler handler})
      : _handler = handler,
        super(const AudioState()) {
    _initListeners();
  }

  void _initListeners() {
    _playbackSub = _handler.playbackState.listen((ps) {
      if (ps.processingState == AudioProcessingState.completed) {
        _onTrackCompleted();
        return;
      }
      state = state.copyWith(
        isPlaying: ps.playing,
        position: ps.position,
      );
    });

    _mediaItemSub = _handler.mediaItem.listen((item) {
      if (item != null) {
        // Sync currentUrl/currentIndex when the handler advances tracks
        // autonomously (autoplay, media notification). MediaItem.id == song.id.
        final matchIndex = state.queue.indexWhere((s) => s.id == item.id);
        state = state.copyWith(
          currentTitle: item.title,
          currentArtist: item.artist,
          duration: item.duration ?? Duration.zero,
          currentUrl: matchIndex >= 0 ? state.queue[matchIndex].audioUrl : null,
          currentIndex: matchIndex >= 0 ? matchIndex : null,
        );
      }
    });
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    _mediaItemSub?.cancel();
    super.dispose();
  }

  Future<void> load(String url, {required String title, required String artist}) async {
    if (url == state.currentUrl) return;
    final song = Song(
      id: url,
      title: title,
      artist: artist,
      audioUrl: url,
      durationIds: 0,
    );
    state = state.copyWith(
      currentUrl: url,
      currentTitle: title,
      currentArtist: artist,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
      queue: [song],
      currentIndex: 0,
    );
    await _handler.setQueue([song], startIndex: 0, autoPlay: false);
  }

  /// Plays or resumes audio for the given [url].
  ///
  /// CONTRACT: In the current app, this method is only called AFTER [setQueue]
  /// has already loaded the audio source into the handler (via
  /// [BetelAudioHandler.setQueue] → [_loadAndPlay]). Calling [_handler.play()]
  /// here is therefore always a resume of an already-loaded source, never a
  /// cold-start load.
  ///
  /// Do NOT call this method standalone for a new URL without first calling
  /// [setQueue]; [_handler.play()] would call [AudioPlayer.play()] on whatever
  /// was last loaded (or be a no-op if nothing was loaded).
  Future<void> play(String url, {required String title, required String artist}) async {
    if (url == state.currentUrl && !state.isPlaying) {
      await resume();
      return;
    }

    state = state.copyWith(
      currentUrl: url,
      currentTitle: title,
      currentArtist: artist,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
    );

    await _handler.play();
  }

  Future<void> pause() async {
    await _handler.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    await _handler.play();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> stop() async {
    await _handler.stop();
    if (mounted) {
      state = const AudioState();
    }
  }

  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    await _handler.seek(position);
  }

  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) return;
    state = state.copyWith(
      queue: songs,
      currentIndex: startIndex,
      currentUrl: songs[startIndex].audioUrl,
    );
    await _handler.setQueue(songs, startIndex: startIndex);
  }

  Future<void> toggleRepeat() async {
    final next = switch (state.repeatMode) {
      AudioRepeatMode.off => AudioRepeatMode.all,
      AudioRepeatMode.all => AudioRepeatMode.one,
      AudioRepeatMode.one => AudioRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
    _handler.setRepeatOne(next == AudioRepeatMode.one);
  }

  Future<void> toggleShuffle() async {
    final next = state.shuffleMode == AudioShuffleMode.off ? AudioShuffleMode.on : AudioShuffleMode.off;
    state = state.copyWith(shuffleMode: next);
    if (next == AudioShuffleMode.on) {
      _rebuildShuffleIndices();
    }
  }

  void _rebuildShuffleIndices() {
    final queue = state.queue;
    final current = state.currentIndex ?? 0;
    final indices = List<int>.generate(queue.length, (i) => i)..remove(current);
    indices.shuffle(Random());
    // Current track stays at position 0 so "next" skips it
    _shuffledIndices = [current, ...indices];
  }

  Future<void> playNext() async {
    final queue = state.queue;
    final index = state.currentIndex;
    if (queue.isEmpty || index == null) return;

    if (state.shuffleMode == AudioShuffleMode.on && _shuffledIndices.isNotEmpty) {
      final pos = _shuffledIndices.indexOf(index);
      final nextPos = (pos + 1) % _shuffledIndices.length;
      final nextIndex = _shuffledIndices[nextPos];
      state = state.copyWith(currentIndex: nextIndex);
      await _handler.skipToIndex(nextIndex);
      return;
    }

    final isLast = index >= queue.length - 1;
    if (isLast) {
      if (state.repeatMode == AudioRepeatMode.all) {
        state = state.copyWith(currentIndex: 0);
        await _handler.skipToNext();
      }
      return;
    }

    state = state.copyWith(currentIndex: index + 1);
    await _handler.skipToNext();
  }

  Future<void> playPrevious() async {
    final queue = state.queue;
    final index = state.currentIndex;
    if (queue.isEmpty || index == null) return;

    if (state.shuffleMode == AudioShuffleMode.on && _shuffledIndices.isNotEmpty) {
      final pos = _shuffledIndices.indexOf(index);
      final prevPos = (pos - 1 + _shuffledIndices.length) % _shuffledIndices.length;
      final prevIndex = _shuffledIndices[prevPos];
      state = state.copyWith(currentIndex: prevIndex);
      await _handler.skipToIndex(prevIndex);
      return;
    }

    if (index > 0) {
      state = state.copyWith(currentIndex: index - 1);
    }
    // At index 0, skipToPrevious() seeks to Duration.zero (restart current song).
    await _handler.skipToPrevious();
  }

  void _onTrackCompleted() {
    if (state.repeatMode == AudioRepeatMode.one) {
      state = state.copyWith(position: Duration.zero, isPlaying: true);
      return;
    }

    if (state.repeatMode == AudioRepeatMode.all) {
      final queue = state.queue;
      if (queue.isEmpty) return;
      final index = state.currentIndex ?? 0;
      if (index >= queue.length - 1) {
        state = state.copyWith(currentIndex: 0, position: Duration.zero);
        _handler.skipToIndex(0);
      }
      return;
    }

    state = state.copyWith(isPlaying: false, position: Duration.zero);
  }
}
