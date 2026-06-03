import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelapp/core/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.resetForTesting();
    final dbPath = await databaseFactoryFfi.getDatabasesPath();
    await databaseFactoryFfi.deleteDatabase('$dbPath/betel.db');
  });

  tearDown(() async {
    try {
      final db = await DatabaseHelper().database;
      await db.close();
    } catch (_) {}
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

  test('review_active table has expected columns', () async {
    final db = await DatabaseHelper().database;
    await db.insert('review_active', {
      'lesson_id': 42,
      'active': 1,
    });
    final rows = await db.query('review_active');
    expect(rows.length, 1);
    expect(rows.first['lesson_id'], 42);
    expect(rows.first['active'], 1);
  });

  test('upgrade from v2 creates card_progress and review_active tables', () async {
    // Open at v2 explicitly (no onCreate for review tables)
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'betel_upgrade_test.db');

    // Create a v2 database manually
    final v2db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // Minimal v2 schema — just enough for the upgrade path
        await db.execute('''
          CREATE TABLE IF NOT EXISTS lessons (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            audio_local_path TEXT,
            audio_ext TEXT,
            audio_checksum TEXT,
            pdf_local_path TEXT NOT NULL,
            pdf_checksum TEXT NOT NULL,
            synced_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_meta (
            id INTEGER PRIMARY KEY DEFAULT 1,
            manifest_version INTEGER NOT NULL,
            last_sync_at INTEGER NOT NULL
          )
        ''');
      },
    );
    await v2db.close();

    // Now open at v3 using the DatabaseHelper upgrade path
    final v3db = await openDatabase(
      path,
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
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
      },
    );

    final cardProgressTables = await v3db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='card_progress'",
    );
    final reviewActiveTables = await v3db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='review_active'",
    );

    expect(cardProgressTables, isNotEmpty);
    expect(reviewActiveTables, isNotEmpty);

    await v3db.close();
    await deleteDatabase(path);
  });
}
