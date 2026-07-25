import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show inMemoryDatabasePath;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelapp/core/database_helper.dart';

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

  test('database version is 6', () async {
    final db = await DatabaseHelper().database;
    expect(await db.getVersion(), 6);
  });

  test('lessons table exists with correct columns', () async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery("PRAGMA table_info(lessons)");
    final columns = result.map((r) => r['name'] as String).toSet();
    expect(columns, containsAll([
      'id', 'title', 'audio_local_path', 'audio_ext',
      'audio_checksum', 'pdf_local_path', 'pdf_checksum', 'synced_at',
      'question_count'
    ]));
  });

  test('sync_meta table exists with correct columns', () async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery("PRAGMA table_info(sync_meta)");
    final columns = result.map((r) => r['name'] as String).toSet();
    expect(columns, containsAll(['id', 'manifest_version', 'last_sync_at']));
  });

  test('contents table exists with correct columns', () async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery("PRAGMA table_info(contents)");
    final columns = result.map((r) => r['name'] as String).toSet();
    expect(columns, containsAll([
      'id', 'slug', 'title', 'type', 'youtube_url', 'html',
      'pages_html', 'display_location', 'synced_at',
    ]));
  });

  // Regression: upgrading from v3 (1.1.6) to v6 (1.2.5) must not throw
  // "duplicate column" when the ALTER TABLE steps overlap with _createContentTables.
  test('upgrade from v3 to current does not throw duplicate column error', () async {
    const tmpPath = '/tmp/betel_migration_v3_test.db';
    DatabaseHelper.resetForTesting(dbPath: tmpPath);

    // Bootstrap a v3 database manually.
    final seedDb = await databaseFactoryFfi.openDatabase(
      tmpPath,
      options: OpenDatabaseOptions(version: 3, onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE lesson_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lesson_id INTEGER NOT NULL UNIQUE,
            is_completed INTEGER NOT NULL DEFAULT 0,
            is_locked INTEGER NOT NULL DEFAULT 1,
            last_accessed INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE favorites (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            item_id TEXT NOT NULL,
            added_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS lessons (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            audio_local_path TEXT,
            audio_ext TEXT,
            audio_checksum TEXT,
            pdf_local_path TEXT NOT NULL,
            pdf_checksum TEXT NOT NULL,
            synced_at INTEGER NOT NULL,
            question_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_meta (
            id INTEGER PRIMARY KEY DEFAULT 1,
            manifest_version INTEGER NOT NULL,
            last_sync_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS card_progress (
            question_id INTEGER PRIMARY KEY,
            lesson_id INTEGER NOT NULL,
            bucket INTEGER NOT NULL DEFAULT 1,
            last_reviewed_at TEXT,
            next_review_at TEXT NOT NULL,
            question_text TEXT,
            answer_text TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS review_active (
            lesson_id INTEGER PRIMARY KEY,
            active INTEGER NOT NULL DEFAULT 0
          )
        ''');
      }),
    );
    await seedDb.close();

    // Now open via DatabaseHelper — this must run _onUpgrade without throwing.
    DatabaseHelper.resetForTesting(dbPath: tmpPath);
    final db = await DatabaseHelper().database;
    expect(await db.getVersion(), 6);

    final result = await db.rawQuery("PRAGMA table_info(contents)");
    final columns = result.map((r) => r['name'] as String).toSet();
    expect(columns, containsAll(['pages_html', 'display_location']));

    await db.close();
    await databaseFactoryFfi.deleteDatabase(tmpPath);
  });
}
