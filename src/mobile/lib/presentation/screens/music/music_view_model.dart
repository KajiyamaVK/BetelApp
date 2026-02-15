import 'package:betelsas/core/providers.dart';
import 'package:betelsas/data/models/song.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final musicViewModelProvider = StateNotifierProvider<MusicViewModel, AsyncValue<List<Song>>>((ref) {
  return MusicViewModel(ref);
});

class MusicViewModel extends StateNotifier<AsyncValue<List<Song>>> {
  final Ref _ref;

  MusicViewModel(this._ref) : super(const AsyncValue.loading()) {
    loadSongs();
  }

  Future<void> loadSongs() async {
    try {
      final repository = _ref.read(contentRepositoryProvider);
      final lessons = await repository.loadLessons();
      // Extract songs from lessons
      final songs = lessons
          .where((l) => l.song != null)
          .map((l) => l.song!)
          .toList();
      
      state = AsyncValue.data(songs);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
