import 'dart:async';
import 'package:betelapp/core/network_status_notifier.dart';
import 'package:betelapp/core/providers.dart';
import 'package:betelapp/core/theme/app_theme.dart';
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

  // Dev hack: long-press (10s) on Revisões tab advances all cards by 1 day
  Timer? _reviewLongPressTimer;
  bool _longPressActive = false;

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
    _reviewLongPressTimer?.cancel();
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

  void _onReviewTabLongPressStart() {
    _longPressActive = true;
    _reviewLongPressTimer = Timer(const Duration(seconds: 10), () async {
      if (!_longPressActive || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Avançar 1 dia de revisão?'),
          content: const Text(
            'Todos os cards terão sua data de revisão antecipada em 1 dia. '
            'Isso não altera o relógio do sistema — apenas a fila interna.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await ref.read(reviewRepositoryProvider).advanceOneDayForTesting();
        await ref.read(reviewViewModelProvider.notifier).loadState();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏩ Avançou 1 dia na fila de revisões'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _onReviewTabLongPressEnd() {
    _longPressActive = false;
    _reviewLongPressTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final networkStatus = ref.watch(networkStatusProvider);
    return Scaffold(
      body: Column(
        children: [
          if (networkStatus != NetworkStatus.ok)
            _ConnectivityBanner(status: networkStatus),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
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
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Lições',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.music_note_rounded),
            label: 'Músicas',
          ),
          BottomNavigationBarItem(
            icon: GestureDetector(
              onLongPressStart: (_) => _onReviewTabLongPressStart(),
              onLongPressEnd: (_) => _onReviewTabLongPressEnd(),
              onLongPressCancel: _onReviewTabLongPressEnd,
              child: const Icon(Icons.style_rounded),
            ),
            label: 'Revisões',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favoritos',
          ),
        ],
      ),
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  final NetworkStatus status;
  const _ConnectivityBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final isServerDown = status == NetworkStatus.serverDown;
    return Material(
      color: isServerDown ? AppTheme.errorColor : Colors.grey[700],
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isServerDown
                      ? 'Servidor indisponível. Verificando...'
                      : 'Sem conexão com a internet. Verificando...',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
