import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/repositories/content_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;

  setUp(() {
    DatabaseHelper.resetForTesting(dbPath: inMemoryDatabasePath);
    dbHelper = DatabaseHelper();
  });

  tearDown(() async {
    final db = await dbHelper.database;
    await db.close();
    DatabaseHelper.resetForTesting();
  });

  test('loadContents returns all contents ordered by id', () async {
    final db = await dbHelper.database;
    await db.insert('contents', {
      'id': 2, 'slug': 'about', 'title': 'About', 'type': 'TEXT',
      'html': '<p>Hi</p>', 'synced_at': 0,
    });
    await db.insert('contents', {
      'id': 1, 'slug': 'welcome', 'title': 'Welcome', 'type': 'VIDEO',
      'youtube_url': 'https://youtube.com/watch?v=abc', 'synced_at': 0,
    });

    final repo = ContentRepository(dbHelper: dbHelper);
    final contents = await repo.loadContents();

    expect(contents.length, 2);
    expect(contents[0].id, 1);
    expect(contents[0].slug, 'welcome');
    expect(contents[1].id, 2);
    expect(contents[1].slug, 'about');
  });

  test('loadContents returns empty list when no contents exist', () async {
    final repo = ContentRepository(dbHelper: dbHelper);
    final contents = await repo.loadContents();
    expect(contents, isEmpty);
  });

  test('loadContentBySlug returns content matching the slug', () async {
    final db = await dbHelper.database;
    await db.insert('contents', {
      'id': 1, 'slug': 'welcome-video', 'title': 'Welcome', 'type': 'VIDEO',
      'youtube_url': 'https://youtube.com/watch?v=abc', 'synced_at': 0,
    });

    final repo = ContentRepository(dbHelper: dbHelper);
    final content = await repo.loadContentBySlug('welcome-video');

    expect(content, isNotNull);
    expect(content!.id, 1);
    expect(content.title, 'Welcome');
    expect(content.type, 'VIDEO');
  });

  test('loadContentBySlug returns null when slug not found', () async {
    final repo = ContentRepository(dbHelper: dbHelper);
    final content = await repo.loadContentBySlug('nonexistent');
    expect(content, isNull);
  });
}
