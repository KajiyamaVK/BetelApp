import 'dart:io';
import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/data/models/lesson.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:betelsas/presentation/screens/favorites/favorites_view_model.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  String? localPdfPath;

  @override
  void initState() {
    super.initState();
    if (widget.lesson.pdfUrl != null) {
      _preparePdf(widget.lesson.pdfUrl!);
    }
  }

  Future<void> _preparePdf(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${assetPath.split('/').last}');

      await file.writeAsBytes(bytes, flush: true);
      setState(() {
        localPdfPath = file.path;
      });
    } catch (e) {
      debugPrint('Error preparing PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lesson.pdfUrl != null) {
      return _buildPdfLayout(ref);
    }
    return _buildTextLayout(ref);
  }

  Widget _buildFavoriteIcon() {
    final favoritesState = ref.watch(favoritesViewModelProvider);
    
    return favoritesState.when(
      data: (favorites) {
        final isFav = favorites.any((item) => item is Lesson && item.id == widget.lesson.id);
        return Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: Colors.white,
        );
      },
      loading: () => const Icon(Icons.favorite_border_rounded, color: Colors.white),
      error: (_, __) => const Icon(Icons.favorite_border_rounded, color: Colors.white),
    );
  }

  Widget _buildPdfLayout(WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.lesson.title,
          style: AppTheme.heading2.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: _buildFavoriteIcon(),
            onPressed: () {
              ref.read(favoritesViewModelProvider.notifier).toggleFavorite(
                'lesson', 
                widget.lesson.id.toString(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (localPdfPath != null)
            Padding(
              padding: EdgeInsets.only(bottom: widget.lesson.song != null ? 100 : 0),
              child: PdfViewer.file(
                localPdfPath!,
                params: const PdfViewerParams(
                  maxScale: 3.0,
                  // Enable momentum scrolling
                  scrollPhysics: BouncingScrollPhysics(),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (widget.lesson.song != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _LessonAudioPlayer(song: widget.lesson.song!),
            ),
        ],
      ),
    );
  }

  Widget _buildTextLayout(WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
          IconButton(
            icon: _buildFavoriteIcon(),
            onPressed: () {
              ref.read(favoritesViewModelProvider.notifier).toggleFavorite(
                'lesson', 
                widget.lesson.id.toString(),
              );
            },
          ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/lesson_${widget.lesson.id}.png', // Ensure assets exist or mock
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: AppTheme.primaryColor),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'LIÇÃO ${widget.lesson.id}',
                                style: AppTheme.caption
                                    .copyWith(fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.lesson.title,
                              style: AppTheme.heading1.copyWith(color: Colors.white),
                            ),

                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildScriptureCard(widget.lesson.scriptureReference),
                      const SizedBox(height: 24),
                      Text(
                        widget.lesson.content,
                        style: AppTheme.bodyText.copyWith(height: 1.6, fontSize: 18),
                      ),
                      const SizedBox(height: 100), // Space for audio player
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (widget.lesson.song != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _LessonAudioPlayer(song: widget.lesson.song!),
            ),
        ],
      ),
    );
  }

  Widget _buildScriptureCard(String reference) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(
            reference,
            style: AppTheme.heading2.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _LessonAudioPlayer extends ConsumerWidget {
  final Song song;

  const _LessonAudioPlayer({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final isLoaded = audioState.currentUrl == song.audioUrl;

    if (!isLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(audioProvider.notifier).load(
          song.audioUrl,
          title: song.title,
          artist: song.artist,
        );
      });
    }

    return const AudioPlayerWidget(showRestartButton: false);
  }
}
