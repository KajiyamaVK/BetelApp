import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static String? _testDbPath;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static void resetForTesting({String? dbPath}) {
    _database = null;
    _instance = DatabaseHelper._internal();
    _testDbPath = dbPath;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path;
    if (_testDbPath != null) {
      path = _testDbPath!;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, 'betel.db');
    }
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createOriginalTables(db);
    await _createSyncTables(db);
    await _createReviewTables(db);
    await _createContentTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSyncTables(db);
    }
    if (oldVersion < 3) {
      await _createReviewTables(db);
      // Add question_count to lessons table if upgrading from v2
      await db.execute('ALTER TABLE lessons ADD COLUMN question_count INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      // _createContentTables already includes pages_html and display_location,
      // so ALTER TABLE steps below must be skipped for this path.
      await _createContentTables(db);
    }
    if (oldVersion >= 4 && oldVersion < 5) {
      await db.execute('ALTER TABLE contents ADD COLUMN pages_html TEXT');
    }
    if (oldVersion >= 4 && oldVersion < 6) {
      await db.execute("ALTER TABLE contents ADD COLUMN display_location TEXT NOT NULL DEFAULT 'HOME'");
    }
    if (oldVersion < 6) {
      // Any upgrade to v6 leaves local content rows out of sync with the manifest:
      // the contents table is freshly (empty) created when coming from < v4, and
      // display_location is backfilled with the literal 'HOME' default when coming
      // from v4/v5. ContentSyncService.sync() would otherwise skip re-population
      // whenever the manifest version is unchanged (its version gate), so help
      // content would stay at 'HOME' and be unreachable by its HELP_* location.
      // Invalidate the sync checkpoint so the next online sync re-inserts every
      // content with its real display_location.
      await db.update('sync_meta', {'manifest_version': -1});
    }
  }

  Future<void> _createOriginalTables(Database db) async {
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
  }

  Future<void> _createReviewTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS card_progress (
        question_id       INTEGER PRIMARY KEY,
        lesson_id         INTEGER NOT NULL,
        bucket            INTEGER NOT NULL DEFAULT 1,
        last_reviewed_at  TEXT,
        next_review_at    TEXT NOT NULL,
        question_text     TEXT,
        answer_text       TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS review_active (
        lesson_id INTEGER PRIMARY KEY,
        active    INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createContentTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contents (
        id               INTEGER PRIMARY KEY,
        slug             TEXT NOT NULL UNIQUE,
        title            TEXT NOT NULL,
        type             TEXT NOT NULL,
        youtube_url      TEXT,
        html             TEXT,
        pages_html       TEXT,
        display_location TEXT NOT NULL DEFAULT 'HOME',
        synced_at        INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lessons (
        id               INTEGER PRIMARY KEY,
        title            TEXT NOT NULL,
        audio_local_path TEXT,
        audio_ext        TEXT,
        audio_checksum   TEXT,
        pdf_local_path   TEXT NOT NULL,
        pdf_checksum     TEXT NOT NULL,
        synced_at        INTEGER NOT NULL,
        question_count   INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        id               INTEGER PRIMARY KEY DEFAULT 1,
        manifest_version INTEGER NOT NULL,
        last_sync_at     INTEGER NOT NULL
      )
    ''');
  }
}
