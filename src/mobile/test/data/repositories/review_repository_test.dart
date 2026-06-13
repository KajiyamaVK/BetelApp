import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show inMemoryDatabasePath;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/models/flashcard.dart';
import 'package:betelapp/data/repositories/review_repository_impl.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.resetForTesting(dbPath: inMemoryDatabasePath);
  });

  tearDown(() async {
    final db = await DatabaseHelper().database;
    await db.close();
    DatabaseHelper.resetForTesting(dbPath: inMemoryDatabasePath);
  });

  group('ReviewRepository — card_progress', () {
    late ReviewRepositoryImpl repo;

    setUp(() {
      repo = ReviewRepositoryImpl(DatabaseHelper());
    });

    test('getDueCards returns empty when no cards exist', () async {
      final cards = await repo.getDueCards(lessonIds: [1]);
      expect(cards, isEmpty);
    });

    test('upsertCards inserts new flashcards with bucket 1', () async {
      final flashcards = [
        const Flashcard(id: 1, lessonId: 1, question: 'Q?', answer: 'A.'),
        const Flashcard(id: 2, lessonId: 1, question: 'Q2?', answer: 'A2.'),
      ];
      await repo.upsertCards(flashcards);

      final db = await DatabaseHelper().database;
      final rows = await db.query('card_progress');
      expect(rows.length, 2);
      expect(rows.first['bucket'], 1);
    });

    test('upsertCards does NOT reset bucket for existing cards', () async {
      final flashcard = const Flashcard(id: 10, lessonId: 1, question: 'Q?', answer: 'A.');
      await repo.upsertCards([flashcard]);

      final db = await DatabaseHelper().database;
      await db.update('card_progress', {'bucket': 3}, where: 'question_id = ?', whereArgs: [10]);

      await repo.upsertCards([flashcard]);

      final rows = await db.query('card_progress', where: 'question_id = ?', whereArgs: [10]);
      expect(rows.first['bucket'], 3);
    });

    test('recordAnswer — correct answer advances bucket and sets nextReviewAt', () async {
      final flashcard = const Flashcard(id: 20, lessonId: 1, question: 'Q?', answer: 'A.');
      await repo.upsertCards([flashcard]);

      final now = DateTime(2026, 6, 2);
      await repo.recordAnswer(questionId: 20, correct: true, answeredAt: now);

      final db = await DatabaseHelper().database;
      final rows = await db.query('card_progress', where: 'question_id = ?', whereArgs: [20]);
      expect(rows.first['bucket'], 2);
      final nextReview = DateTime.parse(rows.first['next_review_at'] as String);
      expect(nextReview, DateTime(2026, 6, 4)); // bucket 2 → 2 days
    });

    test('recordAnswer — wrong answer resets bucket to 1 and nextReviewAt is tomorrow', () async {
      final flashcard = const Flashcard(id: 21, lessonId: 1, question: 'Q?', answer: 'A.');
      await repo.upsertCards([flashcard]);

      final db = await DatabaseHelper().database;
      await db.update('card_progress', {'bucket': 4}, where: 'question_id = ?', whereArgs: [21]);

      final now = DateTime(2026, 6, 2);
      await repo.recordAnswer(questionId: 21, correct: false, answeredAt: now);

      final rows = await db.query('card_progress', where: 'question_id = ?', whereArgs: [21]);
      expect(rows.first['bucket'], 1);
      final nextReview = DateTime.parse(rows.first['next_review_at'] as String);
      expect(nextReview, DateTime(2026, 6, 3)); // bucket 1 → 1 day
    });

    test('recordAnswer — bucket 5 correct answer stays at bucket 5 with 16-day interval', () async {
      final flashcard = const Flashcard(id: 50, lessonId: 1, question: 'Q?', answer: 'A.');
      await repo.upsertCards([flashcard]);

      final db = await DatabaseHelper().database;
      await db.update('card_progress', {'bucket': 5}, where: 'question_id = ?', whereArgs: [50]);

      final now = DateTime(2026, 6, 2);
      await repo.recordAnswer(questionId: 50, correct: true, answeredAt: now);

      final rows = await db.query('card_progress', where: 'question_id = ?', whereArgs: [50]);
      expect(rows.first['bucket'], 5);
      final nextReview = DateTime.parse(rows.first['next_review_at'] as String);
      expect(nextReview, DateTime(2026, 6, 18)); // bucket 5 → 16 days
    });

    test('getDueCards returns only cards with nextReviewAt <= today', () async {
      final db = await DatabaseHelper().database;
      await db.insert('card_progress', {
        'question_id': 30,
        'lesson_id': 1,
        'bucket': 1,
        'next_review_at': '2026-06-01T00:00:00.000',
      });
      await db.insert('card_progress', {
        'question_id': 31,
        'lesson_id': 1,
        'bucket': 2,
        'next_review_at': '2026-06-10T00:00:00.000',
      });

      final due = await repo.getDueCards(lessonIds: [1], today: DateTime(2026, 6, 2));
      expect(due.length, 1);
      expect(due.first.questionId, 30);
    });

    test('advanceOneDayForTesting subtracts 1 day from all next_review_at', () async {
      final db = await DatabaseHelper().database;
      await db.insert('card_progress', {
        'question_id': 60,
        'lesson_id': 1,
        'bucket': 2,
        'next_review_at': '2026-06-10T00:00:00.000',
      });
      await db.insert('card_progress', {
        'question_id': 61,
        'lesson_id': 1,
        'bucket': 3,
        'next_review_at': '2026-06-05T00:00:00.000',
      });

      await repo.advanceOneDayForTesting();

      final rows = await db.query('card_progress', where: 'question_id IN (60, 61)', orderBy: 'question_id');
      expect(DateTime.parse(rows[0]['next_review_at'] as String), DateTime(2026, 6, 9));
      expect(DateTime.parse(rows[1]['next_review_at'] as String), DateTime(2026, 6, 4));
    });

    test('deleteCardsForQuestionIds removes specified cards', () async {
      final db = await DatabaseHelper().database;
      await db.insert('card_progress', {'question_id': 40, 'lesson_id': 5, 'bucket': 1, 'next_review_at': '2026-06-02T00:00:00.000'});
      await db.insert('card_progress', {'question_id': 41, 'lesson_id': 5, 'bucket': 1, 'next_review_at': '2026-06-02T00:00:00.000'});

      await repo.deleteCardsForQuestionIds([40, 41]);

      final rows = await db.query('card_progress', where: 'lesson_id = ?', whereArgs: [5]);
      expect(rows, isEmpty);
    });
  });

  group('ReviewRepository — review_active', () {
    late ReviewRepositoryImpl repo;

    setUp(() {
      repo = ReviewRepositoryImpl(DatabaseHelper());
    });

    test('isReviewActive returns false for unregistered lesson', () async {
      final active = await repo.isReviewActive(lessonId: 99);
      expect(active, false);
    });

    test('setReviewActive true then false works correctly', () async {
      await repo.setReviewActive(lessonId: 1, active: true);
      expect(await repo.isReviewActive(lessonId: 1), true);

      await repo.setReviewActive(lessonId: 1, active: false);
      expect(await repo.isReviewActive(lessonId: 1), false);
    });

    test('getActiveLessonIds returns only lessons with active=1', () async {
      await repo.setReviewActive(lessonId: 1, active: true);
      await repo.setReviewActive(lessonId: 2, active: true);
      await repo.setReviewActive(lessonId: 3, active: false);

      final activeIds = await repo.getActiveLessonIds();
      expect(activeIds, containsAll([1, 2]));
      expect(activeIds, isNot(contains(3)));
    });

    // Regression: new lessons with Q&A must default to active after first sync.
    test('setReviewActive(true) resets card_progress for that lesson to bucket 1 and next_review_at=today', () async {
      // Arrange: insert cards at advanced buckets with future review dates
      final db = await DatabaseHelper().database;
      await db.insert('card_progress', {
        'question_id': 100,
        'lesson_id': 5,
        'bucket': 4,
        'next_review_at': '2026-06-20T00:00:00.000',
        'last_reviewed_at': '2026-06-10T00:00:00.000',
        'question_text': 'Q1?',
        'answer_text': 'A1.',
      });
      await db.insert('card_progress', {
        'question_id': 101,
        'lesson_id': 5,
        'bucket': 3,
        'next_review_at': '2026-06-15T00:00:00.000',
        'last_reviewed_at': '2026-06-08T00:00:00.000',
        'question_text': 'Q2?',
        'answer_text': 'A2.',
      });
      // Card from a DIFFERENT lesson — must NOT be affected
      await db.insert('card_progress', {
        'question_id': 200,
        'lesson_id': 99,
        'bucket': 5,
        'next_review_at': '2026-07-01T00:00:00.000',
        'question_text': 'Other?',
        'answer_text': 'Other.',
      });

      // Act: toggle review ON for lesson 5
      await repo.setReviewActive(lessonId: 5, active: true);

      // Assert: lesson 5 cards are reset
      final lesson5Cards = await db.query('card_progress',
          where: 'lesson_id = ?', whereArgs: [5], orderBy: 'question_id');
      expect(lesson5Cards.length, 2);
      for (final card in lesson5Cards) {
        expect(card['bucket'], 1, reason: 'card ${card['question_id']} bucket should be 1');
        final nextReview = DateTime.parse(card['next_review_at'] as String);
        final now = DateTime.now();
        // next_review_at should be today (within a few seconds of now)
        expect(nextReview.year, now.year);
        expect(nextReview.month, now.month);
        expect(nextReview.day, now.day);
      }

      // Assert: lesson 99 card is untouched
      final otherCards = await db.query('card_progress',
          where: 'lesson_id = ?', whereArgs: [99]);
      expect(otherCards.first['bucket'], 5);
      expect(otherCards.first['next_review_at'], '2026-07-01T00:00:00.000');
    });

    test('setReviewActive(false) does NOT reset card_progress', () async {
      // Arrange: card at bucket 4
      final db = await DatabaseHelper().database;
      await db.insert('card_progress', {
        'question_id': 110,
        'lesson_id': 6,
        'bucket': 4,
        'next_review_at': '2026-06-20T00:00:00.000',
        'question_text': 'Q?',
        'answer_text': 'A.',
      });

      // Act: toggle review OFF
      await repo.setReviewActive(lessonId: 6, active: false);

      // Assert: card is untouched
      final rows = await db.query('card_progress',
          where: 'question_id = ?', whereArgs: [110]);
      expect(rows.first['bucket'], 4);
      expect(rows.first['next_review_at'], '2026-06-20T00:00:00.000');
    });

    // Regression: new lessons with Q&A must default to active after first sync.
    test('activateReviewIfNew sets active=true when no row exists', () async {
      await repo.activateReviewIfNew(lessonId: 10);
      expect(await repo.isReviewActive(lessonId: 10), isTrue);
    });

    test('activateReviewIfNew does NOT override an explicit setReviewActive(false)', () async {
      await repo.setReviewActive(lessonId: 11, active: false);
      await repo.activateReviewIfNew(lessonId: 11);
      expect(await repo.isReviewActive(lessonId: 11), isFalse,
          reason: 'user explicitly deactivated — re-sync must not override that choice');
    });

    test('activateReviewIfNew does NOT override an explicit setReviewActive(true)', () async {
      await repo.setReviewActive(lessonId: 12, active: true);
      await repo.activateReviewIfNew(lessonId: 12);
      expect(await repo.isReviewActive(lessonId: 12), isTrue);
    });
  });
}
