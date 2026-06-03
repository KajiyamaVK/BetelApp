import 'package:betelapp/core/providers.dart';
import 'package:betelapp/core/theme/app_theme.dart';
import 'package:betelapp/data/models/lesson.dart';
import 'package:betelapp/presentation/providers/audio_provider.dart';
import 'package:betelapp/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:betelapp/presentation/screens/favorites/favorites_view_model.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  String? localPdfPath;
  bool _isPdfReady = false;

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
          if (widget.lesson.questionCount > 0)
            _ReviewToggleButton(lessonId: widget.lesson.id),
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
                params: PdfViewerParams(
                  maxScale: 3.0,
                  scrollPhysics: const BouncingScrollPhysics(),
                  verticalCacheExtent: 100.0,
                  onViewerReady: (_, __) {
                    if (mounted) setState(() => _isPdfReady = true);
                  },
                ),
              ),
            ),
          if (!_isPdfReady)
            const Center(
              key: Key('lesson-pdf-loading'),
              child: CircularProgressIndicator(),
            ),
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
  AudioNotifier? _audioNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioNotifier ??= ref.read(audioProvider.notifier);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initAudio();
    });
  }

  @override
  void dispose() {
    _audioNotifier?.stop();
    super.dispose();
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
    return const AudioPlayerWidget(
      key: ValueKey('lesson-screen-player'),
      showShuffle: false,
    );
  }
}

class _ReviewToggleButton extends ConsumerStatefulWidget {
  final int lessonId;

  const _ReviewToggleButton({required this.lessonId});

  @override
  ConsumerState<_ReviewToggleButton> createState() => _ReviewToggleButtonState();
}

class _ReviewToggleButtonState extends ConsumerState<_ReviewToggleButton> {
  bool? _isActive;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final repo = ref.read(reviewRepositoryProvider);
    final active = await repo.isReviewActive(lessonId: widget.lessonId);
    if (mounted) setState(() => _isActive = active);
  }

  Future<void> _toggle() async {
    if (_isActive == null) return;
    final repo = ref.read(reviewRepositoryProvider);
    final newActive = !_isActive!;
    await repo.setReviewActive(lessonId: widget.lessonId, active: newActive);
    ref.read(reviewViewModelProvider.notifier).loadState();
    if (mounted) setState(() => _isActive = newActive);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isActive ?? false;
    return IconButton(
      icon: Icon(
        Icons.style_rounded,
        color: isActive ? AppTheme.primaryColor : Colors.white54,
      ),
      tooltip: isActive ? 'Revisão ativa' : 'Ativar revisão',
      onPressed: _isActive == null ? null : _toggle,
    );
  }
}

