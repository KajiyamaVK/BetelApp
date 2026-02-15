import 'package:audioplayers/audioplayers.dart'; // We need this for Duration/PlayerState potentially, or just use Dart's Duration
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioState {
  final bool isPlaying;
  final String? currentUrl;
  final String? currentTitle;
  final String? currentArtist;
  final Duration duration;
  final Duration position;

  const AudioState({
    this.isPlaying = false,
    this.currentUrl,
    this.currentTitle,
    this.currentArtist,
    this.duration = Duration.zero,
    this.position = Duration.zero,
  });

  AudioState copyWith({
    bool? isPlaying,
    String? currentUrl,
    String? currentTitle,
    String? currentArtist,
    Duration? duration,
    Duration? position,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentUrl: currentUrl ?? this.currentUrl,
      currentTitle: currentTitle ?? this.currentTitle,
      currentArtist: currentArtist ?? this.currentArtist,
      duration: duration ?? this.duration,
      position: position ?? this.position,
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
  }

  Future<void> play(String url, {required String title, required String artist}) async {
    // If same song and paused, resume
    if (url == state.currentUrl && !state.isPlaying) {
      await resume();
      return;
    }
    
    // If different song or first play
    // Stop current if any (though setSource/resume usually handles it, good to be explicit for state)
    await _player.stop();
    
    // Check if asset or url
    // Basic check for asset path
    if (url.startsWith('assets/')) {
       final path = url.replaceFirst('assets/', '');
       await _player.setSource(AssetSource(path));
    } else {
       await _player.setSource(UrlSource(url));
    }

    await _player.resume();
    
    state = state.copyWith(
      currentUrl: url,
      currentTitle: title,
      currentArtist: artist,
      isPlaying: true,
      // Reset position/duration for new song, or let listeners update it? 
      // Listeners will update it shortly, but safer to reset position.
      position: Duration.zero, 
    );
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
    state = state.copyWith(
      isPlaying: false, 
      position: Duration.zero,
    );
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    // State update for position will happen via listener, but good to optimistically update
    state = state.copyWith(position: position);
  }
}
