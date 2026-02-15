import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelsas/presentation/screens/home/home_screen.dart';
import 'package:betelsas/presentation/screens/music/music_screen.dart';
import 'package:betelsas/presentation/screens/flashcards/dashboard.dart';
import 'package:betelsas/presentation/screens/flashcards/dashboard_view_model.dart';
import 'package:betelsas/presentation/screens/favorites/favorites_screen.dart';


class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MusicScreen(),
    const FlashcardDashboard(),
    const FavoritesScreen(),
  ];

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
          if (index == 2) {
             // Reset the flashcards state (filter back to All) when tapping the tab
             ref.invalidate(flashcardDashboardProvider);
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
            icon: Icon(Icons.style_rounded), // Deck/Cards
            label: 'Cards',
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
