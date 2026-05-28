import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioPlayerWidget extends ConsumerStatefulWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool showShuffle;

  const AudioPlayerWidget({
    super.key,
    this.onPrevious,
    this.onNext,
    this.showShuffle = true,
  });

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  bool _isDragging = false;
  double? _dragValue;

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);

    final currentPosition = _isDragging
        ? Duration(seconds: _dragValue?.toInt() ?? 0)
        : audioState.position;

    final maxDuration = audioState.duration.inSeconds.toDouble();
    final value = currentPosition.inSeconds
        .toDouble()
        .clamp(0.0, maxDuration > 0 ? maxDuration : 0.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audioState.currentTitle ?? 'Desconhecido',
                        style: AppTheme.heading2.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        audioState.currentArtist ?? 'Desconhecido',
                        style: AppTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(_formatTime(currentPosition), style: AppTheme.caption),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: maxDuration > 0 ? maxDuration : 1.0,
                    value: value,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: Colors.grey.withValues(alpha: 0.3),
                    onChangeStart: (_) => setState(() => _isDragging = true),
                    onChangeEnd: (val) {
                      ref.read(audioProvider.notifier).seek(Duration(seconds: val.toInt()));
                      setState(() {
                        _isDragging = false;
                        _dragValue = null;
                      });
                    },
                    onChanged: (val) {
                      setState(() => _dragValue = val);
                    },
                  ),
                ),
                Text(_formatTime(audioState.duration), style: AppTheme.caption),
              ],
            ),
            // Controls + toggle row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.showShuffle)
                  _ToggleButton(
                    icon: Icons.shuffle_rounded,
                    active: audioState.shuffleMode == AudioShuffleMode.on,
                    onPressed: () => ref.read(audioProvider.notifier).toggleShuffle(),
                  )
                else
                  const SizedBox(width: 36),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onPrevious != null) ...[
                      _CircleButton(
                        size: 34,
                        onPressed: widget.onPrevious!,
                        icon: Icons.skip_previous_rounded,
                        iconSize: 20,
                      ),
                      const SizedBox(width: 6),
                    ],
                    _CircleButton(
                      size: 42,
                      onPressed: () {
                        if (audioState.isPlaying) {
                          ref.read(audioProvider.notifier).pause();
                        } else {
                          ref.read(audioProvider.notifier).resume();
                        }
                      },
                      icon: audioState.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      iconSize: 26,
                    ),
                    if (widget.onNext != null) ...[
                      const SizedBox(width: 6),
                      _CircleButton(
                        size: 34,
                        onPressed: widget.onNext!,
                        icon: Icons.skip_next_rounded,
                        iconSize: 20,
                      ),
                    ],
                  ],
                ),
                _RepeatButton(
                  mode: audioState.repeatMode,
                  onPressed: () => ref.read(audioProvider.notifier).toggleRepeat(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  const _ToggleButton({
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: active ? Colors.grey[700] : Colors.grey[350],
        size: 22,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  final AudioRepeatMode mode;
  final VoidCallback onPressed;

  const _RepeatButton({required this.mode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isActive = mode != AudioRepeatMode.off;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        mode == AudioRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
        color: isActive ? Colors.grey[700] : Colors.grey[350],
        size: 22,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final double size;
  final VoidCallback onPressed;
  final IconData icon;
  final double iconSize;

  const _CircleButton({
    required this.size,
    required this.onPressed,
    required this.icon,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize, color: Colors.black),
      ),
    );
  }
}
