import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/data/models/lesson.dart';
import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
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
    _preparePdf();
  }

  Future<void> _preparePdf() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fullPath = '${dir.path}/${widget.lesson.localPdfPath}';
      if (mounted) {
        setState(() {
          localPdfPath = fullPath;
        });
      }
    } catch (e) {
      debugPrint('Error resolving PDF path: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildPdfLayout(ref);
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
    final hasAudio = widget.lesson.localAudioPath != null;
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
              padding: EdgeInsets.only(bottom: hasAudio ? 100 : 0),
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
          if (hasAudio)
            Align(
              alignment: Alignment.bottomCenter,
              child: _LessonAudioPlayer(lesson: widget.lesson),
            ),
        ],
      ),
    );
  }
}

class _LessonAudioPlayer extends ConsumerStatefulWidget {
  final Lesson lesson;

  const _LessonAudioPlayer({required this.lesson});

  @override
  ConsumerState<_LessonAudioPlayer> createState() => _LessonAudioPlayerState();
}

class _LessonAudioPlayerState extends ConsumerState<_LessonAudioPlayer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initAudio();
    });
  }

  Future<void> _initAudio() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioUrl = '${dir.path}/${widget.lesson.localAudioPath!}';
    if (!mounted) return;
    final audioState = ref.read(audioProvider);
    if (audioState.currentUrl != audioUrl) {
      await ref.read(audioProvider.notifier).load(
        audioUrl,
        title: widget.lesson.title,
        artist: 'Betel',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AudioPlayerWidget();
  }
}

