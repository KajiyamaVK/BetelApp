import 'package:betelsas/data/models/flashcard.dart';
import 'package:betelsas/data/repositories/flashcard_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelsas/core/providers.dart';

class FlashcardDashboardState {
  final List<FlashcardWithStatus> allCards;
  final List<FlashcardWithStatus> filteredCards;
  final FlashcardStatus? filter;

  FlashcardDashboardState({
    required this.allCards,
    required this.filteredCards,
    this.filter,
  });

  factory FlashcardDashboardState.initial() {
    return FlashcardDashboardState(
      allCards: [],
      filteredCards: [],
      filter: null,
    );
  }

  FlashcardDashboardState copyWith({
    List<FlashcardWithStatus>? allCards,
    List<FlashcardWithStatus>? filteredCards,
    FlashcardStatus? filter,
  }) {
    return FlashcardDashboardState(
      allCards: allCards ?? this.allCards,
      filteredCards: filteredCards ?? this.filteredCards,
      filter: filter ?? this.filter,
    );
  }
}

final flashcardDashboardProvider = StateNotifierProvider<FlashcardDashboardViewModel, AsyncValue<FlashcardDashboardState>>((ref) {
  return FlashcardDashboardViewModel(ref.read(flashcardRepositoryProvider));
});

class FlashcardDashboardViewModel extends StateNotifier<AsyncValue<FlashcardDashboardState>> {
  final FlashcardRepository _repository;

  FlashcardDashboardViewModel(this._repository) : super(const AsyncValue.loading()) {
    loadCards();
  }

  Future<void> loadCards() async {
    try {
      final allCards = await _repository.getAllFlashcardsWithStatus();
      state = AsyncValue.data(FlashcardDashboardState(
        allCards: allCards,
        filteredCards: allCards, // Default shows all
        filter: null,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void setFilter(FlashcardStatus? filter) {
    state.whenData((currentState) {
      final allCards = currentState.allCards;
      List<FlashcardWithStatus> filtered;

      if (filter == null) {
        filtered = allCards;
      } else {
        filtered = allCards.where((c) => c.status == filter).toList();
      }

      state = AsyncValue.data(FlashcardDashboardState(
        allCards: currentState.allCards,
        filteredCards: filtered,
        filter: filter,
      ));
    });
  }

  Future<void> resetAllCards() async {
    try {
      await _repository.resetProgress();
      await loadCards(); // Reload to reflect changes
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
