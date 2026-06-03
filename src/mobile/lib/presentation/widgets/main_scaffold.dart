import 'dart:async';
import 'package:betelapp/core/providers.dart';
import 'package:betelapp/data/services/content_sync_service.dart';
import 'package:betelapp/presentation/screens/reviews/reviews_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelapp/presentation/screens/home/home_screen.dart';
import 'package:betelapp/presentation/screens/music/music_screen.dart';
import 'package:betelapp/presentation/screens/reviews/reviews_screen.dart';
import 'package:betelapp/presentation/screens/favorites/favorites_screen.dart';
import 'package:betelapp/presentation/providers/audio_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final SyncResult? syncResult;
  const MainScaffold({super.key, this.syncResult});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  // Dev hack: 10 taps on Revisões tab resets all review progress
  int _reviewTabTapCount = 0;
  Timer? _reviewTapTimer;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(syncResult: widget.syncResult),
      const MusicScreen(),
      const ReviewsScreen(),
      const FavoritesScreen(),
    ];
  }

  @override
  void dispose() {
    _reviewTapTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleReviewTabTap() async {
    _reviewTabTapCount++;
    _reviewTapTimer?.cancel();
    _reviewTapTimer = Timer(const Duration(seconds: 3), () {
      _reviewTabTapCount = 0;
    });

    if (_reviewTabTapCount >= 10) {
      _reviewTabTapCount = 0;
      _reviewTapTimer?.cancel();
      await ref.read(reviewRepositoryProvider).resetAllProgress();
      await ref.read(reviewViewModelProvider.notifier).loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 Progresso de revisão resetado'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_currentIndex == 1 && index != 1) {
            ref.read(audioProvider.notifier).stop();
          }
          if (index == 2) _handleReviewTabTap();
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Lições',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_rounded),
            label: 'Músicas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.style_rounded),
            label: 'Revisões',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favoritos',
          ),
        ],
      ),
    );
  }
}
