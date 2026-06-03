import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/models/flashcard.dart';
import 'package:betelapp/domain/repositories/review_repository.dart';
import 'package:sqflite/sqflite.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final DatabaseHelper _dbHelper;

  // Bucket index → days until next review (index = bucket number)
  static const List<int> _bucketIntervalDays = [0, 1, 2, 4, 8, 16];

  ReviewRepositoryImpl(this._dbHelper);

  @override
  Future<void> upsertCards(List<Flashcard> flashcards) async {
    final db = await _dbHelper.database;
    final tomorrow = DateTime.now().add(const Duration(days: 1)).toIso8601String();

    for (final flashcard in flashcards) {
      final existing = await db.query(
        'card_progress',
        where: 'question_id = ?',
        whereArgs: [flashcard.id],
      );
      if (existing.isEmpty) {
        await db.insert('card_progress', {
          'question_id': flashcard.id,
          'lesson_id': flashcard.lessonId,
          'bucket': 1,
          'next_review_at': tomorrow,
        });
      }
      // Existing cards are left untouched — preserves Leitner progress
    }
  }

  @override
  Future<void> recordAnswer({
    required int questionId,
    required bool correct,
    DateTime? answeredAt,
  }) async {
    final db = await _dbHelper.database;
    final now = answeredAt ?? DateTime.now();

    final rows = await db.query('card_progress', where: 'question_id = ?', whereArgs: [questionId]);
    if (rows.isEmpty) return;

    final currentBucket = rows.first['bucket'] as int;
    final newBucket = correct ? (currentBucket + 1).clamp(1, 5) : 1;
    final intervalDays = _bucketIntervalDays[newBucket];
    final nextReviewAt = now.add(Duration(days: intervalDays));

    await db.update(
      'card_progress',
      {
        'bucket': newBucket,
        'last_reviewed_at': now.toIso8601String(),
        'next_review_at': nextReviewAt.toIso8601String(),
      },
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
  }

  @override
  Future<List<CardProgress>> getDueCards({
    required List<int> lessonIds,
    DateTime? today,
  }) async {
    if (lessonIds.isEmpty) return [];
    final db = await _dbHelper.database;
    final cutoff = (today ?? DateTime.now()).toIso8601String();
    final placeholders = List.filled(lessonIds.length, '?').join(', ');

    final rows = await db.rawQuery(
      'SELECT * FROM card_progress WHERE lesson_id IN ($placeholders) AND next_review_at <= ?',
      [...lessonIds, cutoff],
    );
    return rows.map(CardProgress.fromMap).toList();
  }

  @override
  Future<void> deleteCardsForQuestionIds(List<int> questionIds) async {
    if (questionIds.isEmpty) return;
    final db = await _dbHelper.database;
    final placeholders = List.filled(questionIds.length, '?').join(', ');
    await db.rawDelete(
      'DELETE FROM card_progress WHERE question_id IN ($placeholders)',
      questionIds,
    );
  }

  @override
  Future<bool> isReviewActive({required int lessonId}) async {
    final db = await _dbHelper.database;
    final rows = await db.query('review_active', where: 'lesson_id = ?', whereArgs: [lessonId]);
    if (rows.isEmpty) return false;
    return rows.first['active'] == 1;
  }

  @override
  Future<void> setReviewActive({required int lessonId, required bool active}) async {
    final db = await _dbHelper.database;
    await db.insert(
      'review_active',
      {'lesson_id': lessonId, 'active': active ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<int>> getActiveLessonIds() async {
    final db = await _dbHelper.database;
    final rows = await db.query('review_active', where: 'active = 1');
    return rows.map((row) => row['lesson_id'] as int).toList();
  }
}
