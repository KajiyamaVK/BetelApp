import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:betelsas/core/audio/betel_audio_handler.dart';
import 'package:betelsas/core/providers.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioState {
  final bool isPlaying;
  final String? currentUrl;
  final String? currentTitle;
  final String? currentArtist;
  final Duration duration;
  final Duration position;
  final List<Song> queue;
  final int? currentIndex;

  const AudioState({
    this.isPlaying = false,
    this.currentUrl,
    this.currentTitle,
    this.currentArtist,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.queue = const [],
    this.currentIndex,
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
    );
  }
}

final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  final handler = ref.watch(betelAudioHandlerProvider);
  return AudioNotifier(handler: handler);
});

class AudioNotifier extends StateNotifier<AudioState> {
  final BetelAudioHandler _handler;

  StreamSubscription<PlaybackState>? _playbackSub;
  StreamSubscription<MediaItem?>? _mediaItemSub;

  AudioNotifier({required BetelAudioHandler handler})
      : _handler = handler,
        super(const AudioState()) {
    _initListeners();
  }

  void _initListeners() {
    _playbackSub = _handler.playbackState.listen((ps) {
      state = state.copyWith(
        isPlaying: ps.playing,
        position: ps.position,
      );
    });

    _mediaItemSub = _handler.mediaItem.listen((item) {
      if (item != null) {
        state = state.copyWith(
          currentTitle: item.title,
          currentArtist: item.artist,
          duration: item.duration ?? Duration.zero,
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

  Future<void> playNext() async {
    final queue = state.queue;
    final index = state.currentIndex;
    if (queue.isEmpty || index == null || index >= queue.length - 1) return;
    state = state.copyWith(currentIndex: index + 1);
    await _handler.skipToNext();
  }

  Future<void> playPrevious() async {
    final queue = state.queue;
    final index = state.currentIndex;
    if (queue.isEmpty || index == null) return;
    if (index > 0) {
      state = state.copyWith(currentIndex: index - 1);
    }
    // At index 0, skipToPrevious() seeks to Duration.zero (restart current song).
    // Calling the handler unconditionally here is intentional — the asymmetry
    // with playNext() (which returns early at the last song) is by design:
    // "Previous" on the first song restarts it rather than being a no-op.
    await _handler.skipToPrevious();
  }
}
