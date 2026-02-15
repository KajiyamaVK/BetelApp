import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/data/models/flashcard.dart';
import 'package:betelsas/data/repositories/content_repository.dart';
import 'package:betelsas/domain/flashcard_logic.dart';
import 'package:sqflite/sqflite.dart';

class FlashcardRepository {
  final ContentRepository _contentRepository;
  final DatabaseHelper _databaseHelper;

  FlashcardRepository(this._contentRepository, this._databaseHelper);

  Future<List<Flashcard>> getDueFlashcards() async {
    // 1. Load all static flashcards
    final lessons = await _contentRepository.loadLessons();
    final allFlashcards = lessons.expand((l) => l.flashcards).toList();

    // 2. Load progress from SQLite
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> progressMaps = await db.query('flashcard_progress');

    // Create a map for quick access
    final Map<String, Map<String, dynamic>> progressDict = {
      for (var p in progressMaps) p['flashcard_id'] as String: p
    };

    final DateTime now = DateTime.now();
    final List<Flashcard> dueCards = [];

    for (var card in allFlashcards) {
      final progress = progressDict[card.id];

      if (progress == null) {
        // New card, due immediately
        dueCards.add(card);
      } else {
        final int nextReviewMillis = progress['next_review'] as int;
        final DateTime nextReview = DateTime.fromMillisecondsSinceEpoch(nextReviewMillis);

        if (nextReview.isBefore(now)) {
          dueCards.add(card);
        }
      }
    }

    return dueCards;
  }

  Future<List<FlashcardWithStatus>> getAllFlashcardsWithStatus() async {
    // 1. Load all static flashcards
    final lessons = await _contentRepository.loadLessons();
    final allFlashcards = lessons.expand((l) => l.flashcards).toList();

    // 2. Load progress from SQLite
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> progressMaps = await db.query('flashcard_progress');

    // Create a map for quick access
    final Map<String, Map<String, dynamic>> progressDict = {
      for (var p in progressMaps) p['flashcard_id'] as String: p
    };

    final DateTime now = DateTime.now();
    final List<FlashcardWithStatus> result = [];

    for (var card in allFlashcards) {
      final progress = progressDict[card.id];
      FlashcardStatus status;

      if (progress == null) {
        status = FlashcardStatus.newCard;
      } else {
        final int nextReviewMillis = progress['next_review'] as int;
        final int box = progress['box'] as int;
        final DateTime nextReview = DateTime.fromMillisecondsSinceEpoch(nextReviewMillis);

        // If card is in Box 0 (Learning/Relearning), it should be Review/Learning
        // regardless of the exact minute/hour of next review.
        if (box == 0 || nextReview.isBefore(now)) {
          status = FlashcardStatus.review;
        } else {
          // If reviewed and not currently due, consider it 'learned' for this simplified logic
          status = FlashcardStatus.learned;
        }
      }
      
      result.add(FlashcardWithStatus(flashcard: card, status: status));
    }

    return result;
  }

  Future<void> recordReview(String flashcardId, String performance) async {
    final db = await _databaseHelper.database;
    final DateTime now = DateTime.now();

    // Get current progress
    final List<Map<String, dynamic>> maps = await db.query(
      'flashcard_progress',
      where: 'flashcard_id = ?',
      whereArgs: [flashcardId],
    );

    int currentBox = 0;
    if (maps.isNotEmpty) {
      currentBox = maps.first['box'] as int;
    }

    // Calculate next review
    final DateTime nextReview = FlashcardLogic.calculateNextReview(now, currentBox, performance);
    
    // Update Box based on performance logic (simplified here)
    // If 'again', reset box to 0. If 'hard', maybe stay same? If 'easy', increment.
    int nextBox = currentBox;
    if (performance == 'again') {
      nextBox = 0;
    } else if (performance == 'easy') {
      nextBox = currentBox + 1;
    }
    // 'hard' could decrease or stay same.

    await db.insert(
      'flashcard_progress',
      {
        'flashcard_id': flashcardId,
        'box': nextBox,
        'next_review': nextReview.millisecondsSinceEpoch,
        'last_reviewed': now.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> resetProgress() async {
    final db = await _databaseHelper.database;
    await db.delete('flashcard_progress');
  }
}
