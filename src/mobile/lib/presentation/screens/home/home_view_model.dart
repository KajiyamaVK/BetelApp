import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelsas/core/providers.dart';
import 'package:betelsas/data/models/lesson.dart';

final homeViewModelProvider = StateNotifierProvider<HomeViewModel, AsyncValue<List<Lesson>>>((ref) {
  return HomeViewModel(ref);
});

class HomeViewModel extends StateNotifier<AsyncValue<List<Lesson>>> {
  final Ref _ref;

  HomeViewModel(this._ref) : super(const AsyncValue.loading()) {
    loadLessons();
  }

  Future<void> loadLessons() async {
    try {
      final repository = _ref.read(contentRepositoryProvider);
      final lessons = await repository.loadLessons();
      state = AsyncValue.data(lessons);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
