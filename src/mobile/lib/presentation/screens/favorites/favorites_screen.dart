import 'package:betelapp/core/theme/app_theme.dart';
import 'package:betelapp/data/models/lesson.dart';
import 'package:betelapp/data/models/song.dart';
import 'package:betelapp/presentation/screens/favorites/favorites_view_model.dart';
import 'package:betelapp/presentation/screens/lesson/lesson_detail_screen.dart';
import 'package:betelapp/presentation/widgets/betel_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesViewModelProvider);

    return Scaffold(
      body: favoritesState.when(
        data: (items) {
          if (items.isEmpty) {
             return Column(
               children: [
                 const BetelHeader(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Favoritos', style: AppTheme.heading1),
                    ),
                  ),
                 Expanded(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey[300]),
                       const SizedBox(height: 16),
                       Text(
                         'Você ainda não tem favoritos.',
                         style: AppTheme.bodyText.copyWith(color: Colors.grey),
                       ),
                     ],
                   ),
                 ),
               ],
             );
          }
          
          return Column(
            children: [
              const BetelHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Favoritos', style: AppTheme.heading1),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is Lesson) {
                      return _buildLessonTile(context, item);
                    } else if (item is Song) {
                      return _buildSongTile(context, item);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildLessonTile(BuildContext context, Lesson lesson) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.book_rounded, color: AppTheme.primaryColor),
        title: Text(lesson.title, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
        subtitle: const Text('Lição'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
            Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonDetailScreen(lesson: lesson),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongTile(BuildContext context, Song song) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.music_note_rounded, color: AppTheme.primaryColor),
        title: Text(song.title, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
        subtitle: const Text('Música'),
        trailing: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryColor),
        onTap: () {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Vá para a aba de Músicas para tocar!')),
           );
        },
      ),
    );
  }
}
