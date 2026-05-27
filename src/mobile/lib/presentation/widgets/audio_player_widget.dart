import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioPlayerWidget extends ConsumerStatefulWidget {
  final VoidCallback? onNext;
  final bool showRestartButton;

  const AudioPlayerWidget({
    super.key,
    this.onNext,
    this.showRestartButton = true,
  });

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  // Local state for smooth slider dragging
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
    final notifier = ref.read(audioProvider.notifier);

    final currentPosition = _isDragging 
        ? Duration(seconds: _dragValue?.toInt() ?? 0) 
        : audioState.position;
    
    final maxDuration = audioState.duration.inSeconds.toDouble();
    final value = currentPosition.inSeconds.toDouble().clamp(0.0, maxDuration > 0 ? maxDuration : 0.0);

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
                  child: const Icon(Icons.music_note_rounded, color: AppTheme.primaryColor),
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
                if (widget.showRestartButton) ...[
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        notifier.seek(Duration.zero);
                      },
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        size: 24,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      if (audioState.isPlaying) {
                        notifier.pause();
                      } else {
                        notifier.resume();
                      }
                    },
                    icon: Icon(
                      audioState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 32,
                      color: Colors.black,
                    ),
                  ),
                ),
                if (widget.onNext != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: widget.onNext,
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        size: 24,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
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
                      setState(() {
                         _isDragging = false;
                         _dragValue = null;
                      });
                      notifier.seek(Duration(seconds: val.toInt()));
                    },
                    onChanged: (val) {
                      setState(() => _dragValue = val);
                    },
                  ),
                ),
                Text(_formatTime(audioState.duration), style: AppTheme.caption),
              ],
            )
          ],
        ),
      ),
    );
  }
}
