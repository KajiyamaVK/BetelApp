import 'dart:io';
import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/data/models/lesson.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:betelsas/presentation/screens/favorites/favorites_view_model.dart';
import 'package:betelsas/data/models/lesson.dart';

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
              child: _buildAudioControl(ref),
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
              child: _buildAudioControl(ref),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioControl(WidgetRef ref) {
    final audioState = ref.watch(audioProvider);
    final isPlayingThis = audioState.currentUrl == widget.lesson.song!.audioUrl;

    if (isPlayingThis) {
      return const AudioPlayerWidget();
    }

    // "Start Playing" Placeholder that matches AudioPlayerWidget style
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
        child: Row(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.lesson.song!.title, 
                    style: AppTheme.heading2.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.lesson.song!.artist, 
                    style: AppTheme.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  ref.read(audioProvider.notifier).play(
                    widget.lesson.song!.audioUrl,
                    title: widget.lesson.song!.title,
                    artist: widget.lesson.song!.artist,
                  );
                },
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  size: 32,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
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
