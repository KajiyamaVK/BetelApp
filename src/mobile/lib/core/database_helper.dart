import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'betel.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Lesson Progress Table
    await db.execute('''
      CREATE TABLE lesson_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL UNIQUE,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 1,
        last_accessed INTEGER
      )
    ''');

    // Favorites Table
    await db.execute('''
      CREATE TABLE favorites (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL, -- 'lesson' or 'song'
        item_id TEXT NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');

    // Flashcard Progress Table (for SM-2 or similar)
    await db.execute('''
      CREATE TABLE flashcard_progress (
        flashcard_id TEXT PRIMARY KEY,
        box INTEGER NOT NULL DEFAULT 0, -- Leitner box or interval
        next_review INTEGER NOT NULL, -- Timestamp
        last_reviewed INTEGER
      )
    ''');
  }

  // Helper methods could be added here or in repositories
}
