import 'package:betelapp/core/providers.dart';
import 'package:betelapp/data/models/song.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final favoritesViewModelProvider = StateNotifierProvider<FavoritesViewModel, AsyncValue<List<dynamic>>>((ref) {
  return FavoritesViewModel(ref);
});

class FavoritesViewModel extends StateNotifier<AsyncValue<List<dynamic>>> {
  final Ref _ref;

  FavoritesViewModel(this._ref) : super(const AsyncValue.loading()) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    try {
      final repo = _ref.read(favoritesRepositoryProvider);
      final favorites = await repo.getFavorites();

      final contentRepo = _ref.read(contentRepositoryProvider);
      final lessons = await contentRepo.loadLessonsWithAudio();
      final dir = await getApplicationDocumentsDirectory();
      final songs = lessons
          .where((l) => l.localAudioPath != null)
          .map((l) => Song(
                id: l.id.toString(),
                title: l.title,
                artist: 'Betel',
                audioUrl: '${dir.path}/${l.localAudioPath!}',
                durationIds: 0,
              ))
          .toList();

      final List<dynamic> favoriteItems = [];

      for (var fav in favorites) {
        if (fav.type == 'lesson') {
           final lessonId = int.tryParse(fav.itemId);
           if (lessonId != null) {
              try {
                final lesson = lessons.firstWhere((l) => l.id == lessonId);
                favoriteItems.add(lesson);
              } catch (_) {}
           }
        } else if (fav.type == 'song') {
           try {
             final song = songs.firstWhere((s) => s.id == fav.itemId);
             favoriteItems.add(song);
           } catch (_) {}
        }
      }

      state = AsyncValue.data(favoriteItems);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleFavorite(String type, String itemId) async {
    try {
      final repo = _ref.read(favoritesRepositoryProvider);
      final isFav = await repo.isFavorite(type, itemId);

      if (isFav) {
        await repo.removeFavorite(type, itemId);
      } else {
        await repo.addFavorite(type, itemId);
      }

      // Reload favorites to update the list
      await loadFavorites();
    } catch (e) {
      // Handle error or show snackbar via a provider/listener
      debugPrint('Error toggling favorite: $e');
    }
  }

  Future<bool> isFavorite(String type, String itemId) async {
    final repo = _ref.read(favoritesRepositoryProvider);
    return await repo.isFavorite(type, itemId);
  }
}

