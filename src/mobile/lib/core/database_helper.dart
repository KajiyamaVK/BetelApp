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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createOriginalTables(db);
    await _createSyncTables(db);
    await _createReviewTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSyncTables(db);
    }
    if (oldVersion < 3) {
      await _createReviewTables(db);
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
        synced_at        INTEGER NOT NULL
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
