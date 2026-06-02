import 'package:betelapp/data/services/content_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelapp/presentation/screens/home/home_screen.dart';
import 'package:betelapp/presentation/screens/music/music_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(syncResult: widget.syncResult),
      const MusicScreen(),
      const FavoritesScreen(),
    ];
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
            icon: Icon(Icons.favorite_rounded),
            label: 'Favoritos',
          ),
        ],
      ),
    );
  }
}
