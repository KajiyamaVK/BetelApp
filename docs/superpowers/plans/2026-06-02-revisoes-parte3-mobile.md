# Revisões — Parte 3: App Mobile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar a feature completa de revisões no app Flutter: dados SQLite (card_progress + review_active), algoritmo Leitner, tab "Revisões", tela de sessão, e toggle no detalhe da lição.

**Architecture:** Novos dados ficam em SQLite (v3 do schema). `ReviewRepository` gerencia `card_progress` e `review_active`. `ReviewViewModel` (Riverpod `StateNotifierProvider`) alimenta as telas. Manifest é estendido com `questions`. Leitner calcula `nextReviewAt` localmente após cada resposta.

**Tech Stack:** Flutter, Riverpod 2.5.1, sqflite, Dart

**Pré-requisito:** Parte 1 (backend) deve estar implementada — o manifest já precisa incluir `questions`.

---

## Estrutura de arquivos

| Ação | Arquivo |
|------|---------|
| Modify | `lib/core/database_helper.dart` |
| Modify | `lib/data/models/manifest.dart` |
| Create | `lib/data/models/flashcard.dart` |
| Create | `lib/domain/repositories/review_repository.dart` |
| Create | `lib/data/repositories/review_repository_impl.dart` |
| Modify | `lib/data/services/content_sync_service.dart` |
| Create | `lib/presentation/screens/reviews/reviews_screen.dart` |
| Create | `lib/presentation/screens/reviews/reviews_view_model.dart` |
| Create | `lib/presentation/screens/reviews/review_session_screen.dart` |
| Modify | `lib/presentation/screens/lesson/lesson_detail_screen.dart` |
| Modify | `lib/presentation/widgets/main_scaffold.dart` |
| Modify | `lib/core/providers.dart` |
| Create | `test/data/repositories/review_repository_test.dart` |
| Create | `test/presentation/screens/reviews/reviews_view_model_test.dart` |
| Modify | `src/mobile/pubspec.yaml` (version bump) |

---

### Task 7: Schema SQLite v3 — tabelas card_progress e review_active

**Files:**
- Modify: `lib/core/database_helper.dart`

- [ ] **Step 1: Escrever teste falhando para criação das tabelas**

Criar `test/core/database_helper_v3_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelapp/core/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.resetForTesting();
  });

  tearDown(() async {
    final db = await DatabaseHelper().database;
    await db.close();
    DatabaseHelper.resetForTesting();
  });

  test('database v3 creates card_progress table', () async {
    final db = await DatabaseHelper().database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='card_progress'",
    );
    expect(tables, isNotEmpty);
  });

  test('database v3 creates review_active table', () async {
    final db = await DatabaseHelper().database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='review_active'",
    );
    expect(tables, isNotEmpty);
  });

  test('card_progress table has expected columns', () async {
    final db = await DatabaseHelper().database;
    await db.insert('card_progress', {
      'question_id': 1,
      'lesson_id': 1,
      'bucket': 1,
      'last_reviewed_at': '2026-06-02T10:00:00.000Z',
      'next_review_at': '2026-06-03T10:00:00.000Z',
    });
    final rows = await db.query('card_progress');
    expect(rows.length, 1);
    expect(rows.first['question_id'], 1);
    expect(rows.first['bucket'], 1);
  });
}
```

- [ ] **Step 2: Rodar e confirmar falha**

```bash
cd src/mobile
flutter test test/core/database_helper_v3_test.dart
```

Esperado: falha — tabelas não existem.

- [ ] **Step 3: Atualizar DatabaseHelper para v3**

Em `lib/core/database_helper.dart`, bumpar `version` para 3 e adicionar migração:

```dart
// Alterar a linha de version:
version: 3,

// Adicionar ao onUpgrade:
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await _createSyncTables(db);
  }
  if (oldVersion < 3) {
    await _createReviewTables(db);
  }
}

// Adicionar ao onCreate (chamar _createReviewTables também):
Future<void> _onCreate(Database db, int version) async {
  await _createOriginalTables(db);
  await _createSyncTables(db);
  await _createReviewTables(db);
}

// Novo método:
Future<void> _createReviewTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS card_progress (
      question_id     INTEGER PRIMARY KEY,
      lesson_id       INTEGER NOT NULL,
      bucket          INTEGER NOT NULL DEFAULT 1,
      last_reviewed_at TEXT,
      next_review_at  TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS review_active (
      lesson_id INTEGER PRIMARY KEY,
      active    INTEGER NOT NULL DEFAULT 0
    )
  ''');
}
```

- [ ] **Step 4: Rodar e confirmar verde**

```bash
cd src/mobile
flutter test test/core/database_helper_v3_test.dart
```

Esperado: todos os testes passando.

- [ ] **Step 5: Commit**

```bash
git add src/mobile/lib/core/database_helper.dart \
        src/mobile/test/core/database_helper_v3_test.dart
git commit -m "feat(mobile): add card_progress and review_active tables (SQLite v3)"
```

---

### Task 8: Modelo Flashcard e extensão do ManifestLesson

**Files:**
- Create: `lib/data/models/flashcard.dart`
- Modify: `lib/data/models/manifest.dart`

- [ ] **Step 1: Criar modelo Flashcard**

Criar `lib/data/models/flashcard.dart`:

```dart
class Flashcard {
  final int id;
  final int lessonId;
  final String question;
  final String answer;

  const Flashcard({
    required this.id,
    required this.lessonId,
    required this.question,
    required this.answer,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json, int lessonId) => Flashcard(
        id: json['id'] as int,
        lessonId: lessonId,
        question: json['q'] as String,
        answer: json['a'] as String,
      );
}

class CardProgress {
  final int questionId;
  final int lessonId;
  final int bucket;
  final DateTime? lastReviewedAt;
  final DateTime nextReviewAt;

  const CardProgress({
    required this.questionId,
    required this.lessonId,
    required this.bucket,
    this.lastReviewedAt,
    required this.nextReviewAt,
  });

  factory CardProgress.fromMap(Map<String, dynamic> map) => CardProgress(
        questionId: map['question_id'] as int,
        lessonId: map['lesson_id'] as int,
        bucket: map['bucket'] as int,
        lastReviewedAt: map['last_reviewed_at'] != null
            ? DateTime.parse(map['last_reviewed_at'] as String)
            : null,
        nextReviewAt: DateTime.parse(map['next_review_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'question_id': questionId,
        'lesson_id': lessonId,
        'bucket': bucket,
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
        'next_review_at': nextReviewAt.toIso8601String(),
      };
}
```

- [ ] **Step 2: Estender ManifestLesson com questions**

Em `lib/data/models/manifest.dart`, adicionar classe `ManifestQuestion` e campo `questions` em `ManifestLesson`:

```dart
class ManifestQuestion {
  final int id;
  final String question;
  final String answer;

  const ManifestQuestion({required this.id, required this.question, required this.answer});

  factory ManifestQuestion.fromJson(Map<String, dynamic> json) => ManifestQuestion(
        id: json['id'] as int,
        question: json['q'] as String,
        answer: json['a'] as String,
      );
}

// Atualizar ManifestLesson:
class ManifestLesson {
  final int id;
  final String title;
  final ManifestFileEntry pdf;
  final ManifestAudioEntry? audio;
  final List<ManifestQuestion> questions;  // NOVO

  ManifestLesson({
    required this.id,
    required this.title,
    required this.pdf,
    this.audio,
    this.questions = const [],  // NOVO — default vazio para compatibilidade
  });

  factory ManifestLesson.fromJson(Map<String, dynamic> json) => ManifestLesson(
        id: json['id'] as int,
        title: json['title'] as String,
        pdf: ManifestFileEntry.fromJson(json['pdf'] as Map<String, dynamic>),
        audio: json['audio'] != null
            ? ManifestAudioEntry.fromJson(json['audio'] as Map<String, dynamic>)
            : null,
        questions: json['questions'] != null  // NOVO
            ? (json['questions'] as List)
                .map((q) => ManifestQuestion.fromJson(q as Map<String, dynamic>))
                .toList()
            : [],
      );
}
```

- [ ] **Step 3: Verificar que testes existentes continuam passando**

```bash
cd src/mobile
flutter test
```

Esperado: zero falhas.

- [ ] **Step 4: Commit**

```bash
git add src/mobile/lib/data/models/flashcard.dart \
        src/mobile/lib/data/models/manifest.dart
git commit -m "feat(mobile): add Flashcard model and extend ManifestLesson with questions"
```

---

### Task 9: ReviewRepository — persistência local de Q&As e progresso Leitner

**Files:**
- Create: `lib/domain/repositories/review_repository.dart`
- Create: `lib/data/repositories/review_repository_impl.dart`
- Create: `test/data/repositories/review_repository_test.dart`

- [ ] **Step 1: Escrever testes falhando**

Criar `test/data/repositories/review_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
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
    DatabaseHelper.resetForTesting();
  });

  tearDown(() async {
    final db = await DatabaseHelper().database;
    await db.close();
    DatabaseHelper.resetForTesting();
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
        Flashcard(id: 1, lessonId: 1, question: 'Q?', answer: 'A.'),
        Flashcard(id: 2, lessonId: 1, question: 'Q2?', answer: 'A2.'),
      ];
      await repo.upsertCards(flashcards);

      final db = await DatabaseHelper().database;
      final rows = await db.query('card_progress');
      expect(rows.length, 2);
      expect(rows.first['bucket'], 1);
    });

    test('upsertCards does NOT reset bucket for existing cards', () async {
      final flashcard = Flashcard(id: 10, lessonId: 1, question: 'Q?', answer: 'A.');
      await repo.upsertCards([flashcard]);

      final db = await DatabaseHelper().database;
      await db.update('card_progress', {'bucket': 3}, where: 'question_id = ?', whereArgs: [10]);

      await repo.upsertCards([flashcard]);

      final rows = await db.query('card_progress', where: 'question_id = ?', whereArgs: [10]);
      expect(rows.first['bucket'], 3);
    });

    test('recordAnswer — acertou sobe bucket e calcula nextReviewAt correto', () async {
      final flashcard = Flashcard(id: 20, lessonId: 1, question: 'Q?', answer: 'A.');
      await repo.upsertCards([flashcard]);

      final now = DateTime(2026, 6, 2);
      await repo.recordAnswer(questionId: 20, correct: true, answeredAt: now);

      final db = await DatabaseHelper().database;
      final rows = await db.query('card_progress', where: 'question_id = ?', whereArgs: [20]);
      expect(rows.first['bucket'], 2);
      final nextReview = DateTime.parse(rows.first['next_review_at'] as String);
      expect(nextReview, DateTime(2026, 6, 4));
    });

    test('recordAnswer — errou volta para bucket 1 e nextReviewAt é amanhã', () async {
      final flashcard = Flashcard(id: 21, lessonId: 1, question: 'Q?', answer: 'A.');
      await repo.upsertCards([flashcard]);

      final db = await DatabaseHelper().database;
      await db.update('card_progress', {'bucket': 4}, where: 'question_id = ?', whereArgs: [21]);

      final now = DateTime(2026, 6, 2);
      await repo.recordAnswer(questionId: 21, correct: false, answeredAt: now);

      final rows = await db.query('card_progress', where: 'question_id = ?', whereArgs: [21]);
      expect(rows.first['bucket'], 1);
      final nextReview = DateTime.parse(rows.first['next_review_at'] as String);
      expect(nextReview, DateTime(2026, 6, 3));
    });

    test('getDueCards retorna apenas cards com nextReviewAt <= hoje', () async {
      final db = await DatabaseHelper().database;
      await db.insert('card_progress', {
        'question_id': 30,
        'lesson_id': 1,
        'bucket': 1,
        'next_review_at': '2026-06-01T00:00:00.000Z',
      });
      await db.insert('card_progress', {
        'question_id': 31,
        'lesson_id': 1,
        'bucket': 2,
        'next_review_at': '2026-06-10T00:00:00.000Z',
      });

      final due = await repo.getDueCards(lessonIds: [1], today: DateTime(2026, 6, 2));
      expect(due.length, 1);
      expect(due.first.questionId, 30);
    });

    test('deleteCardsForLesson remove todos os cards de uma lição', () async {
      final db = await DatabaseHelper().database;
      await db.insert('card_progress', {'question_id': 40, 'lesson_id': 5, 'bucket': 1, 'next_review_at': '2026-06-02T00:00:00.000Z'});
      await db.insert('card_progress', {'question_id': 41, 'lesson_id': 5, 'bucket': 1, 'next_review_at': '2026-06-02T00:00:00.000Z'});

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

    test('isReviewActive retorna false para lição não registrada', () async {
      final active = await repo.isReviewActive(lessonId: 99);
      expect(active, false);
    });

    test('setReviewActive true e depois false funciona corretamente', () async {
      await repo.setReviewActive(lessonId: 1, active: true);
      expect(await repo.isReviewActive(lessonId: 1), true);

      await repo.setReviewActive(lessonId: 1, active: false);
      expect(await repo.isReviewActive(lessonId: 1), false);
    });

    test('getActiveLessonIds retorna apenas lições com active=1', () async {
      await repo.setReviewActive(lessonId: 1, active: true);
      await repo.setReviewActive(lessonId: 2, active: true);
      await repo.setReviewActive(lessonId: 3, active: false);

      final activeIds = await repo.getActiveLessonIds();
      expect(activeIds, containsAll([1, 2]));
      expect(activeIds, isNot(contains(3)));
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar falha**

```bash
cd src/mobile
flutter test test/data/repositories/review_repository_test.dart
```

Esperado: falha — `ReviewRepositoryImpl` não existe.

- [ ] **Step 3: Criar interface abstrata**

Criar `lib/domain/repositories/review_repository.dart`:

```dart
import 'package:betelapp/data/models/flashcard.dart';

abstract class ReviewRepository {
  Future<void> upsertCards(List<Flashcard> flashcards);
  Future<void> recordAnswer({
    required int questionId,
    required bool correct,
    DateTime? answeredAt,
  });
  Future<List<CardProgress>> getDueCards({
    required List<int> lessonIds,
    DateTime? today,
  });
  Future<void> deleteCardsForQuestionIds(List<int> questionIds);
  Future<bool> isReviewActive({required int lessonId});
  Future<void> setReviewActive({required int lessonId, required bool active});
  Future<List<int>> getActiveLessonIds();
}
```

- [ ] **Step 4: Criar implementação**

Criar `lib/data/repositories/review_repository_impl.dart`:

```dart
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/models/flashcard.dart';
import 'package:betelapp/domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final DatabaseHelper _dbHelper;

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
```

Adicionar import no topo do arquivo:
```dart
import 'package:sqflite/sqflite.dart';
```

- [ ] **Step 5: Rodar e confirmar verde**

```bash
cd src/mobile
flutter test test/data/repositories/review_repository_test.dart
```

Esperado: todos os testes passando.

- [ ] **Step 6: Rodar suite completa**

```bash
cd src/mobile
flutter test
```

Esperado: zero regressões.

- [ ] **Step 7: Commit**

```bash
git add src/mobile/lib/domain/repositories/review_repository.dart \
        src/mobile/lib/data/repositories/review_repository_impl.dart \
        src/mobile/test/data/repositories/review_repository_test.dart
git commit -m "feat(mobile): add ReviewRepository with Leitner algorithm"
```

---

### Task 10: ReviewViewModel e providers

**Files:**
- Create: `lib/presentation/screens/reviews/reviews_view_model.dart`
- Modify: `lib/core/providers.dart`
- Create: `test/presentation/screens/reviews/reviews_view_model_test.dart`

- [ ] **Step 1: Criar ReviewViewModel**

Criar `lib/presentation/screens/reviews/reviews_view_model.dart`:

```dart
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/models/flashcard.dart';
import 'package:betelapp/data/repositories/review_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewSummary {
  final int lessonId;
  final String lessonTitle;
  final int dueCount;
  final int totalCount;
  final bool reviewActive;

  const ReviewSummary({
    required this.lessonId,
    required this.lessonTitle,
    required this.dueCount,
    required this.totalCount,
    required this.reviewActive,
  });
}

class ReviewState {
  final List<ReviewSummary> activeLessons;
  final int totalDueToday;

  const ReviewState({required this.activeLessons, required this.totalDueToday});
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

      final Map<int, int> dueByLesson = {};
      for (final card in dueCards) {
        dueByLesson[card.lessonId] = (dueByLesson[card.lessonId] ?? 0) + 1;
      }

      state = AsyncValue.data(ReviewState(
        activeLessons: [],
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
```

- [ ] **Step 2: Registrar provider em `providers.dart`**

Em `lib/core/providers.dart`, adicionar:

```dart
import 'package:betelapp/data/repositories/review_repository_impl.dart';
import 'package:betelapp/presentation/screens/reviews/reviews_view_model.dart';

final reviewRepositoryProvider = Provider<ReviewRepositoryImpl>(
  (ref) => ReviewRepositoryImpl(DatabaseHelper()),
);

final reviewViewModelProvider =
    StateNotifierProvider<ReviewViewModel, AsyncValue<ReviewState>>(
  (ref) => ReviewViewModel(ref.read(reviewRepositoryProvider)),
);
```

- [ ] **Step 3: Verificar análise estática**

```bash
cd src/mobile
flutter analyze lib/
```

Esperado: sem erros.

- [ ] **Step 4: Commit**

```bash
git add src/mobile/lib/presentation/screens/reviews/reviews_view_model.dart \
        src/mobile/lib/core/providers.dart
git commit -m "feat(mobile): add ReviewViewModel and Riverpod providers"
```

---

### Task 11: Sync — persistir Q&As do manifest no SQLite

**Files:**
- Modify: `lib/data/services/content_sync_service.dart`

- [ ] **Step 1: Atualizar ContentSyncService para persistir Q&As**

Em `lib/data/services/content_sync_service.dart`, após sincronizar uma lição, chamar `repo.upsertCards()` com as Q&As do manifest.

Encontrar o método que salva lições no DB (provavelmente `_syncLesson` ou similar). Após salvar os metadados da lição, adicionar:

```dart
// Persistir Q&As no card_progress (somente insere novas — preserva progresso existente)
final reviewRepo = ReviewRepositoryImpl(DatabaseHelper());
final flashcards = manifestLesson.questions.map((question) => Flashcard(
  id: question.id,
  lessonId: manifestLesson.id,
  question: question.question,
  answer: question.answer,
)).toList();
if (flashcards.isNotEmpty) {
  await reviewRepo.upsertCards(flashcards);
}

// Remover card_progress de Q&As que foram deletadas do manifest
final existingIds = await _getExistingQuestionIdsForLesson(manifestLesson.id);
final manifestIds = manifestLesson.questions.map((q) => q.id).toSet();
final removedIds = existingIds.where((id) => !manifestIds.contains(id)).toList();
if (removedIds.isNotEmpty) {
  await reviewRepo.deleteCardsForQuestionIds(removedIds);
}
```

Adicionar método auxiliar `_getExistingQuestionIdsForLesson`:

```dart
Future<List<int>> _getExistingQuestionIdsForLesson(int lessonId) async {
  final db = await DatabaseHelper().database;
  final rows = await db.query(
    'card_progress',
    columns: ['question_id'],
    where: 'lesson_id = ?',
    whereArgs: [lessonId],
  );
  return rows.map((row) => row['question_id'] as int).toList();
}
```

Adicionar imports necessários no topo:
```dart
import 'package:betelapp/data/models/flashcard.dart';
import 'package:betelapp/data/repositories/review_repository_impl.dart';
```

- [ ] **Step 2: Rodar suite completa**

```bash
cd src/mobile
flutter test
```

Esperado: zero regressões.

- [ ] **Step 3: Commit**

```bash
git add src/mobile/lib/data/services/content_sync_service.dart
git commit -m "feat(mobile): persist Q&As to card_progress during content sync"
```

---

### Task 12: ReviewsScreen — tab Revisões

**Files:**
- Create: `lib/presentation/screens/reviews/reviews_screen.dart`
- Modify: `lib/presentation/widgets/main_scaffold.dart`

- [ ] **Step 1: Criar ReviewsScreen**

Criar `lib/presentation/screens/reviews/reviews_screen.dart`:

```dart
import 'package:betelapp/core/theme/app_theme.dart';
import 'package:betelapp/presentation/screens/reviews/reviews_view_model.dart';
import 'package:betelapp/presentation/screens/reviews/review_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelapp/core/providers.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewState = ref.watch(reviewViewModelProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: SafeArea(
        child: reviewState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erro: $error')),
          data: (state) => _ReviewsContent(state: state),
        ),
      ),
    );
  }
}

class _ReviewsContent extends ConsumerWidget {
  final ReviewState state;

  const _ReviewsContent({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Revisões', style: AppTheme.heading1),
                Text(
                  'MEMORIZAÇÃO DO CATECISMO',
                  style: AppTheme.caption.copyWith(letterSpacing: 1),
                ),
                const SizedBox(height: 16),
                if (state.totalDueToday > 0)
                  _DailyReviewBanner(dueCount: state.totalDueToday),
                const SizedBox(height: 20),
                Text(
                  'LIÇÕES ATIVAS',
                  style: AppTheme.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (state.activeLessons.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nenhuma lição com revisão ativa.\nAbre uma lição e ativa a revisão.',
                  textAlign: TextAlign.center,
                  style: AppTheme.caption,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DailyReviewBanner extends StatelessWidget {
  final int dueCount;

  const _DailyReviewBanner({required this.dueCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVISÃO DO DIA',
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text('Vamos praticar?', style: AppTheme.heading2),
          Text(
            '$dueCount ${dueCount == 1 ? 'card' : 'cards'} para revisar hoje',
            style: AppTheme.bodyText,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReviewSessionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Começar Sessão'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Adicionar 4º tab no MainScaffold**

Em `lib/presentation/widgets/main_scaffold.dart`, adicionar import e 4º tab:

```dart
import 'package:betelapp/presentation/screens/reviews/reviews_screen.dart';

// Em initState, adicionar ao _screens:
_screens = [
  HomeScreen(syncResult: widget.syncResult),
  const MusicScreen(),
  const ReviewsScreen(),  // NOVO — índice 2
  const FavoritesScreen(), // agora índice 3
];

// Na lógica onTap, atualizar o índice do tab Músicas (era index != 1, continua):
onTap: (index) {
  if (_currentIndex == 1 && index != 1) {
    ref.read(audioProvider.notifier).stop();
  }
  setState(() => _currentIndex = index);
},

// Em items, adicionar item de Revisões (entre Músicas e Favoritos):
items: const [
  BottomNavigationBarItem(
    icon: Icon(Icons.menu_book_rounded),
    label: 'Lições',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.music_note_rounded),
    label: 'Músicas',
  ),
  BottomNavigationBarItem(   // NOVO
    icon: Icon(Icons.style_rounded),
    label: 'Revisões',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.favorite_rounded),
    label: 'Favoritos',
  ),
],
```

- [ ] **Step 3: Verificar análise estática**

```bash
cd src/mobile
flutter analyze lib/
```

Esperado: sem erros.

- [ ] **Step 4: Commit**

```bash
git add src/mobile/lib/presentation/screens/reviews/reviews_screen.dart \
        src/mobile/lib/presentation/widgets/main_scaffold.dart
git commit -m "feat(mobile): add Revisões tab and ReviewsScreen"
```

---

### Task 13: ReviewSessionScreen — sessão de revisão

**Files:**
- Create: `lib/presentation/screens/reviews/review_session_screen.dart`

- [ ] **Step 1: Criar ReviewSessionScreen**

Criar `lib/presentation/screens/reviews/review_session_screen.dart`:

```dart
import 'package:betelapp/core/providers.dart';
import 'package:betelapp/core/theme/app_theme.dart';
import 'package:betelapp/data/models/flashcard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  ConsumerState<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen> {
  List<CardProgress> _cards = [];
  int _currentIndex = 0;
  bool _revealed = false;
  int _correctCount = 0;
  int _incorrectCount = 0;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final repo = ref.read(reviewRepositoryProvider);
    final activeIds = await repo.getActiveLessonIds();
    final dueCards = await repo.getDueCards(lessonIds: activeIds);
    setState(() {
      _cards = dueCards;
      _loading = false;
      _finished = dueCards.isEmpty;
    });
  }

  Future<void> _answer(bool correct) async {
    final repo = ref.read(reviewRepositoryProvider);
    await repo.recordAnswer(
      questionId: _cards[_currentIndex].questionId,
      correct: correct,
    );

    if (correct) {
      _correctCount++;
    } else {
      _incorrectCount++;
    }

    if (_currentIndex + 1 >= _cards.length) {
      setState(() => _finished = true);
      ref.read(reviewViewModelProvider.notifier).loadState();
    } else {
      setState(() {
        _currentIndex++;
        _revealed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.lightGrey,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Revisão do dia', style: AppTheme.caption),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _finished
              ? _buildFinishedView()
              : _buildCardView(),
    );
  }

  Widget _buildCardView() {
    final card = _cards[_currentIndex];
    final progress = (_currentIndex + 1) / _cards.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PROGRESSO', style: AppTheme.caption),
              Text(
                'Card ${_currentIndex + 1} de ${_cards.length}',
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              color: AppTheme.primaryColor,
              minHeight: 6,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PERGUNTA', style: AppTheme.caption),
                const SizedBox(height: 12),
                Text(
                  card.questionText ?? '',
                  style: AppTheme.heading2,
                ),
                if (_revealed) ...[
                  Divider(color: AppTheme.primaryColor, thickness: 2),
                  const SizedBox(height: 8),
                  Text('RESPOSTA', style: AppTheme.caption),
                  const SizedBox(height: 6),
                  Text(card.answerText ?? '', style: AppTheme.bodyText),
                ] else ...[
                  const SizedBox(height: 8),
                  Divider(color: AppTheme.primaryColor, thickness: 2),
                ],
              ],
            ),
          ),
          const Spacer(),
          if (!_revealed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _revealed = true),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('REVELAR RESPOSTA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _answer(false),
                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                    label: const Text('ERREI', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _answer(true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('ACERTEI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFinishedView() {
    final total = _correctCount + _incorrectCount;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text('Sessão concluída!', style: AppTheme.heading1),
            const SizedBox(height: 8),
            Text('$_correctCount de $total acertos', style: AppTheme.bodyText),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Nota:** `CardProgress` precisa de campos `questionText` e `answerText` para exibir na UI. Adicionar ao modelo `CardProgress` em `flashcard.dart`:

```dart
class CardProgress {
  // ... campos existentes ...
  final String? questionText;  // NOVO — carregado junto para exibição
  final String? answerText;    // NOVO

  // Atualizar construtor e fromMap para suportar esses campos opcionais
}
```

Alternativamente, criar um `CardProgressWithContent` que une `CardProgress` + `Flashcard` para a UI. Escolher qual abordagem faz mais sentido ao implementar.

- [ ] **Step 2: Verificar análise estática**

```bash
cd src/mobile
flutter analyze lib/
```

Esperado: sem erros (ajustar conforme necessário o modelo `CardProgress`).

- [ ] **Step 3: Commit**

```bash
git add src/mobile/lib/presentation/screens/reviews/review_session_screen.dart \
        src/mobile/lib/data/models/flashcard.dart
git commit -m "feat(mobile): add ReviewSessionScreen with Leitner feedback"
```

---

### Task 14: Toggle de revisão no LessonDetailScreen

**Files:**
- Modify: `lib/presentation/screens/lesson/lesson_detail_screen.dart`

- [ ] **Step 1: Adicionar toggle no AppBar**

Em `lib/presentation/screens/lesson/lesson_detail_screen.dart`, dentro do `AppBar.actions`, adicionar ícone de revisão antes do favorito — **apenas se a lição tiver Q&As no manifest**.

O `widget.lesson` é do tipo `Lesson` (SQLite). A informação de "tem Q&As" vem do manifest — o número de Q&As precisa estar acessível. Opções:
- Adicionar campo `questionCount` ao modelo `Lesson` (SQLite) durante o sync
- Consultar `card_progress` na inicialização da tela

A abordagem mais simples: adicionar `question_count` à tabela `lessons` no SQLite e popular durante o sync. Isso evita uma query extra na tela de detalhe.

Adicionar à migration v3 em `DatabaseHelper._createReviewTables`:
```sql
-- Não é uma tabela nova, é um ALTER. Adicionar em _onUpgrade oldVersion < 3:
ALTER TABLE lessons ADD COLUMN question_count INTEGER NOT NULL DEFAULT 0;
```

Atualizar modelo `Lesson` com `questionCount`:
```dart
// Em lib/data/models/lesson.dart
final int questionCount;  // NOVO

// Atualizar fromMap e toMap
```

Durante o sync, popular `question_count` com `manifestLesson.questions.length`.

No `LessonDetailScreen`, adicionar ao `AppBar.actions`:
```dart
if (widget.lesson.questionCount > 0)
  Consumer(
    builder: (context, ref, _) {
      return FutureBuilder<bool>(
        future: ref.read(reviewRepositoryProvider).isReviewActive(lessonId: widget.lesson.id),
        builder: (context, snapshot) {
          final isActive = snapshot.data ?? false;
          return IconButton(
            icon: Icon(
              Icons.style_rounded,
              color: isActive ? AppTheme.primaryColor : Colors.white54,
            ),
            onPressed: () async {
              await ref.read(reviewRepositoryProvider).setReviewActive(
                lessonId: widget.lesson.id,
                active: !isActive,
              );
              setState(() {});
            },
          );
        },
      );
    },
  ),
```

- [ ] **Step 2: Verificar análise estática**

```bash
cd src/mobile
flutter analyze lib/
```

Esperado: sem erros.

- [ ] **Step 3: Rodar suite completa**

```bash
cd src/mobile
flutter test
```

Esperado: zero regressões.

- [ ] **Step 4: Version bump no pubspec.yaml**

Em `src/mobile/pubspec.yaml`, incrementar `versionCode` em 1 (ex: `1.0.10+14` → `1.0.10+15`).

- [ ] **Step 5: Commit**

```bash
git add src/mobile/lib/presentation/screens/lesson/lesson_detail_screen.dart \
        src/mobile/lib/core/database_helper.dart \
        src/mobile/lib/data/models/lesson.dart \
        src/mobile/pubspec.yaml
git commit -m "feat(mobile): add review toggle to LessonDetailScreen, bump version"
```
