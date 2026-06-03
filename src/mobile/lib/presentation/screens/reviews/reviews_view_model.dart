import 'package:betelapp/data/repositories/review_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewState {
  final List<int> activeLessonIds;
  final int totalDueToday;

  const ReviewState({
    required this.activeLessonIds,
    required this.totalDueToday,
  });

  const ReviewState.empty()
      : activeLessonIds = const [],
        totalDueToday = 0;
}

class ReviewViewModel extends StateNotifier<AsyncValue<ReviewState>> {
  final ReviewRepositoryImpl _repo;

  ReviewViewModel(this._repo) : super(const AsyncValue.loading()) {
    loadState();
  }

  Future<void> loadState() async {
    state = const AsyncValue.loading();
    try {
      final activeIds = await _repo.getActiveLessonIds();
      final dueCards = await _repo.getDueCards(lessonIds: activeIds);
      state = AsyncValue.data(ReviewState(
        activeLessonIds: activeIds,
        totalDueToday: dueCards.length,
      ));
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> toggleReviewActive(int lessonId, bool active) async {
    await _repo.setReviewActive(lessonId: lessonId, active: active);
    await loadState();
  }
}
