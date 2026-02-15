
import 'package:betelsas/presentation/screens/flashcards/dashboard_view_model.dart';
import 'package:betelsas/data/repositories/flashcard_repository.dart';
import 'package:betelsas/data/models/flashcard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'dashboard_view_model_test.mocks.dart';

@GenerateMocks([FlashcardRepository])
void main() {
  late FlashcardDashboardViewModel viewModel;
  late MockFlashcardRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockFlashcardRepository();
    container = ProviderContainer();
    viewModel = FlashcardDashboardViewModel(mockRepository);
  });

  tearDown(() {
    container.dispose();
  });

  group('FlashcardDashboardViewModel', () {
    final card1 = FlashcardWithStatus(
        flashcard: Flashcard(id: '1', question: 'Q1', answer: 'A1'),
        status: FlashcardStatus.newCard);
    final card2 = FlashcardWithStatus(
        flashcard: Flashcard(id: '2', question: 'Q2', answer: 'A2'),
        status: FlashcardStatus.review);
    final card3 = FlashcardWithStatus(
        flashcard: Flashcard(id: '3', question: 'Q3', answer: 'A3'),
        status: FlashcardStatus.learned);

    test('initial state should be loading', () {
      expect(viewModel.state, const AsyncValue<FlashcardDashboardState>.loading());
    });

    test('loadCards should fetch cards and update state', () async {
      // Arrange
      when(mockRepository.getAllFlashcardsWithStatus()).thenAnswer((_) async => [card1, card2, card3]);

      // Act
      await viewModel.loadCards();

      // Assert
      final state = viewModel.state.value!;
      expect(state.allCards, [card1, card2, card3]);
      expect(state.filteredCards, [card1, card2, card3]); // Default filter is All
      expect(state.filter, null);
    });

    test('setFilter should update filteredCards', () async {
      // Arrange
      when(mockRepository.getAllFlashcardsWithStatus()).thenAnswer((_) async => [card1, card2, card3]);
      await viewModel.loadCards();

      // Act - Filter by New
      viewModel.setFilter(FlashcardStatus.newCard);

      // Assert
      expect(viewModel.state.value!.filteredCards, [card1]);
      expect(viewModel.state.value!.filter, FlashcardStatus.newCard);

      // Act - Filter by Review
      viewModel.setFilter(FlashcardStatus.review);

      // Assert
      expect(viewModel.state.value!.filteredCards, [card2]);

      // Act - Filter by All (null)
      viewModel.setFilter(null);

      // Assert
      expect(viewModel.state.value!.filteredCards.length, 3);
    });

    test('resetAllCards should call repository reset and reload cards', () async {
      // Arrange
      when(mockRepository.resetProgress()).thenAnswer((_) async {});
      when(mockRepository.getAllFlashcardsWithStatus()).thenAnswer((_) async => []); // Empty after reset

      // Act
      await viewModel.resetAllCards();

      // Assert
      verify(mockRepository.resetProgress()).called(1);
      verify(mockRepository.getAllFlashcardsWithStatus()).called(2); // Initial load + 1
      expect(viewModel.state.value!.allCards, isEmpty);
    });
  });
}
