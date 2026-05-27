
import 'package:betelsas/data/repositories/flashcard_repository.dart';
import 'package:betelsas/data/models/lesson.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:betelsas/data/repositories/content_repository.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:sqflite/sqflite.dart';

import 'flashcard_repository_test.mocks.dart';

@GenerateMocks([ContentRepository, DatabaseHelper, Database])
void main() {
  late FlashcardRepository repository;
  late MockContentRepository mockContentRepository;
  late MockDatabaseHelper mockDatabaseHelper;
  late MockDatabase mockDatabase;

  setUp(() {
    mockContentRepository = MockContentRepository();
    mockDatabaseHelper = MockDatabaseHelper();
    mockDatabase = MockDatabase();
    repository = FlashcardRepository(mockContentRepository, mockDatabaseHelper);

    when(mockDatabaseHelper.database).thenAnswer((_) async => mockDatabase);
  });

  group('getAllFlashcardsWithStatus', () {
    // After the SQLite migration, lessons no longer carry flashcards. Until a
    // future task reintroduces a flashcards source, the repository returns an
    // empty list. This test pins that behaviour explicitly.
    final testLesson = Lesson(
      id: 1,
      title: 'Test Lesson',
      localPdfPath: 'betelsas/lessons/1/lesson.pdf',
    );

    test('should return an empty list while flashcards source is missing', () async {
      // Arrange
      when(mockContentRepository.loadLessons()).thenAnswer((_) async => [testLesson]);
      when(mockDatabase.query('flashcard_progress')).thenAnswer((_) async => []);

      // Act
      final result = await repository.getAllFlashcardsWithStatus();

      // Assert
      expect(result, isEmpty);
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
