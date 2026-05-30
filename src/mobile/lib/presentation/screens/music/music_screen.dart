import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:betelsas/presentation/screens/music/music_view_model.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:betelsas/presentation/widgets/betel_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsState = ref.watch(musicViewModelProvider);
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          songsState.when(
            data: (songs) {
              if (songs.isEmpty) {
                return const Center(child: Text('Nenhuma música encontrada.'));
              }
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BetelHeader(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Text('Músicas', style: AppTheme.heading1),
                        ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 220),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                        final song = songs[index];
                        final isPlayingThis = audioState.currentUrl == song.audioUrl && audioState.isPlaying;
                        final isCurrent = audioState.currentUrl == song.audioUrl;
      
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor,
                              child: Icon(
                                isCurrent ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                                color: Colors.black,
                              ),
                            ),
                            title: Text(song.title, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
                            subtitle: Text(song.artist, style: AppTheme.caption),
                            trailing: SizedBox(
                              width: 36,
                              height: 36,
                              child: Material(
                                color: isCurrent
                                    ? AppTheme.primaryColor
                                    : AppTheme.primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () async {
                                    if (isPlayingThis) {
                                      await audioNotifier.pause();
                                    } else {
                                      await audioNotifier.setQueue(songs, startIndex: index);
                                    }
                                  },
                                  child: Icon(
                                    isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: isCurrent ? Colors.black : AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                        childCount: songs.length,
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Erro: $e')),
          ),
          
          if (audioState.currentUrl != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: AudioPlayerWidget(
                key: const ValueKey('music-screen-player'),
                onPrevious: () => audioNotifier.playPrevious(),
                onNext: () => audioNotifier.playNext(),
              ),
            ),
        ],
      ),
    );
  }
}
