import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/data/repositories/content_repository.dart';

import 'content_repository_test.mocks.dart';

@GenerateMocks([DatabaseHelper])
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late MockDatabaseHelper mockDb;
  late ContentRepository repo;

  setUp(() {
    mockDb = MockDatabaseHelper();
    repo = ContentRepository(dbHelper: mockDb);
  });

  test('loadLessons returns lessons from SQLite', () async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE lessons (
          id INTEGER PRIMARY KEY, title TEXT NOT NULL,
          audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT,
          pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL,
          synced_at INTEGER NOT NULL
        )
      ''');
      await db.insert('lessons', {
        'id': 1, 'title': 'Qual o Fim principal?',
        'pdf_local_path': 'betelsas/lessons/1/lesson.pdf',
        'pdf_checksum': 'abc',
        'audio_local_path': 'betelsas/lessons/1/audio.mp3',
        'audio_ext': 'mp3', 'audio_checksum': 'def',
        'synced_at': 0,
      });
    });
    when(mockDb.database).thenAnswer((_) async => db);

    final lessons = await repo.loadLessons();
    expect(lessons.length, 1);
    expect(lessons.first.id, 1);
    expect(lessons.first.title, 'Qual o Fim principal?');
    expect(lessons.first.localPdfPath, 'betelsas/lessons/1/lesson.pdf');
    expect(lessons.first.localAudioPath, 'betelsas/lessons/1/audio.mp3');
    expect(lessons.first.audioExt, 'mp3');

    await db.close();
  });

  test('loadLessons returns empty list when no lessons in db', () async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE lessons (
          id INTEGER PRIMARY KEY, title TEXT NOT NULL,
          audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT,
          pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL,
          synced_at INTEGER NOT NULL
        )
      ''');
    });
    when(mockDb.database).thenAnswer((_) async => db);

    final lessons = await repo.loadLessons();
    expect(lessons, isEmpty);

    await db.close();
  });

  test('loadLessonsWithAudio returns only lessons with audio', () async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE lessons (
          id INTEGER PRIMARY KEY, title TEXT NOT NULL,
          audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT,
          pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL,
          synced_at INTEGER NOT NULL
        )
      ''');
      await db.insert('lessons', {
        'id': 1, 'title': 'With Audio',
        'pdf_local_path': 'betelsas/lessons/1/lesson.pdf', 'pdf_checksum': 'abc',
        'audio_local_path': 'betelsas/lessons/1/audio.mp3', 'audio_ext': 'mp3',
        'audio_checksum': 'def', 'synced_at': 0,
      });
      await db.insert('lessons', {
        'id': 2, 'title': 'No Audio',
        'pdf_local_path': 'betelsas/lessons/2/lesson.pdf', 'pdf_checksum': 'ghi',
        'audio_local_path': null, 'audio_ext': null, 'audio_checksum': null, 'synced_at': 0,
      });
    });
    when(mockDb.database).thenAnswer((_) async => db);

    final lessons = await repo.loadLessonsWithAudio();
    expect(lessons.length, 1);
    expect(lessons.first.id, 1);

    await db.close();
  });
}
