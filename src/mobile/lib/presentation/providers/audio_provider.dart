import 'package:audioplayers/audioplayers.dart'; // We need this for Duration/PlayerState potentially, or just use Dart's Duration
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
  return AudioNotifier();
});

class AudioNotifier extends StateNotifier<AudioState> {
  final AudioPlayer _player;
  
  AudioNotifier({AudioPlayer? player}) 
      : _player = player ?? AudioPlayer(),
        super(const AudioState()) {
      
      _initListeners();
  }

  void _initListeners() {
    _player.onPlayerStateChanged.listen((pState) {
      state = state.copyWith(isPlaying: pState == PlayerState.playing);
    });

    _player.onDurationChanged.listen((d) {
      state = state.copyWith(duration: d);
    });

    _player.onPositionChanged.listen((p) {
      state = state.copyWith(position: p);
    });

    _player.onPlayerComplete.listen((_) {
      playNext().catchError((_) {});
    });
  }

  Source _resolveSource(String url) {
    if (url.startsWith('assets/')) {
      return AssetSource(url.replaceFirst('assets/', ''));
    }
    return UrlSource(url);
  }

  Future<void> play(String url, {required String title, required String artist}) async {
    // If same song and paused, resume
    if (url == state.currentUrl && !state.isPlaying) {
      await resume();
      return;
    }

    // Reset state before starting player to avoid race with onDurationChanged/onPositionChanged listeners
    state = state.copyWith(
      currentUrl: url,
      currentTitle: title,
      currentArtist: artist,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
    );

    await _player.stop();
    await _player.setSource(_resolveSource(url));
    await _player.resume();
  }

  Future<void> load(String url, {required String title, required String artist}) async {
    if (url == state.currentUrl) return;

    await _player.stop();

    state = state.copyWith(
      currentUrl: url,
      currentTitle: title,
      currentArtist: artist,
      isPlaying: false,
      position: Duration.zero,
      duration: Duration.zero,
    );

    await _player.setSource(_resolveSource(url));
  }

  Future<void> pause() async {
    await _player.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    await _player.resume();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> stop() async {
    await _player.stop();
    state = const AudioState();
  }

  Future<void> seek(Duration position) async {
    // Optimistic update first so UI responds immediately (and tests can verify it)
    state = state.copyWith(position: position);
    await _player.seek(position);
  }

  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) return;
    state = state.copyWith(
      queue: songs,
      currentIndex: startIndex,
    );
    final song = songs[startIndex];
    await play(song.audioUrl, title: song.title, artist: song.artist);
  }

  Future<void> playNext() async {
    final queue = state.queue;
    final index = state.currentIndex;
    if (queue.isEmpty || index == null) return;
    if (index >= queue.length - 1) return;

    final nextIndex = index + 1;
    final song = queue[nextIndex];
    state = state.copyWith(currentIndex: nextIndex);
    await play(song.audioUrl, title: song.title, artist: song.artist);
  }

  Future<void> playPrevious() async {
    final queue = state.queue;
    final index = state.currentIndex;
    final position = state.position;

    if (position.inSeconds >= 2) {
      await seek(Duration.zero);
      return;
    }

    if (queue.isEmpty || index == null || index <= 0) {
      await seek(Duration.zero);
      return;
    }

    final prevIndex = index - 1;
    final song = queue[prevIndex];
    state = state.copyWith(currentIndex: prevIndex);
    await play(song.audioUrl, title: song.title, artist: song.artist);
  }
}
