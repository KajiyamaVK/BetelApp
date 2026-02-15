
import 'package:betelsas/data/repositories/flashcard_repository.dart';
import 'package:betelsas/data/models/flashcard.dart';
import 'package:betelsas/data/models/lesson.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:betelsas/data/repositories/content_repository.dart';
import 'package:betelsas/core/database_helper.dart';

import 'flashcard_repository_test.mocks.dart';

@GenerateMocks([ContentRepository, DatabaseHelper, Database])
void main() {
  late FlashcardRepository repository;
  late MockContentRepository mockContentRepository;
  late MockDatabaseHelper mockDatabaseHelper;
  late MockDatabase mockDatabase;

  // setUpAll(() {
  //   sqfliteFfiInit();
  //   databaseFactory = databaseFactoryFfi;
  // });

  setUp(() {
    mockContentRepository = MockContentRepository();
    mockDatabaseHelper = MockDatabaseHelper();
    mockDatabase = MockDatabase();
    repository = FlashcardRepository(mockContentRepository, mockDatabaseHelper);

    when(mockDatabaseHelper.database).thenAnswer((_) async => mockDatabase);
  });

  group('getAllFlashcardsWithStatus', () {
    final testLesson = Lesson(
      id: 1,
      title: 'Test Lesson',
      content: 'Content',
      flashcards: [
        Flashcard(id: '1', question: 'Q1', answer: 'A1'),
        Flashcard(id: '2', question: 'Q2', answer: 'A2'),
        Flashcard(id: '3', question: 'Q3', answer: 'A3'),
      ], category: '',
    );

    test('should return all flashcards with correct status', () async {
      // Arrange
      when(mockContentRepository.loadLessons()).thenAnswer((_) async => [testLesson]);
      
      final now = DateTime.now();
      final reviewTime = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch; // Past
      final futureTime = now.add(const Duration(days: 1)).millisecondsSinceEpoch; // Future

      // Mock DB query
      when(mockDatabase.query('flashcard_progress')).thenAnswer((_) async => [
        // Card 2: Review (next_review in past)
        {'flashcard_id': '2', 'next_review': reviewTime, 'box': 1, 'last_reviewed': 0},
        // Card 3: Learned (next_review in future)
        {'flashcard_id': '3', 'next_review': futureTime, 'box': 2, 'last_reviewed': 0},
      ]);

      // Act
      final result = await repository.getAllFlashcardsWithStatus();

      // Assert
      expect(result.length, 3);
      
      // Card 1: New (no record in DB)
      expect(result[0].flashcard.id, '1');
      expect(result[0].status, FlashcardStatus.newCard);

      // Card 2: Review
      expect(result[1].flashcard.id, '2');
      expect(result[1].status, FlashcardStatus.review);

      // Card 3: Learned
      expect(result[2].flashcard.id, '3');
      expect(result[2].status, FlashcardStatus.learned);
    });
  });

  group('resetProgress', () {
    test('should delete all rows from flashcard_progress', () async {
      // Arrange
      when(mockDatabase.delete('flashcard_progress')).thenAnswer((_) async => 5); // Return dummy deleted count

      // Act
      await repository.resetProgress();

      // Assert
      verify(mockDatabase.delete('flashcard_progress')).called(1);
    });
  });
}
