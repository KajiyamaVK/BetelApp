import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/core/connectivity_service.dart';
import 'package:betelapp/data/services/remote_content_service.dart';
import 'package:betelapp/data/services/content_sync_service.dart';
import 'package:betelapp/data/models/manifest.dart';

@GenerateMocks([RemoteContentService, ConnectivityService, DatabaseHelper])
import 'content_sync_service_test.mocks.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late MockRemoteContentService mockRemote;
  late MockConnectivityService mockConnectivity;
  late MockDatabaseHelper mockDb;
  late ContentSyncService service;

  Database? openedDb;

  setUp(() {
    mockRemote = MockRemoteContentService();
    mockConnectivity = MockConnectivityService();
    mockDb = MockDatabaseHelper();
    service = ContentSyncService(
      remote: mockRemote,
      connectivity: mockConnectivity,
      dbHelper: mockDb,
    );
    openedDb = null;
  });

  tearDown(() async {
    await openedDb?.close();
    openedDb = null;
  });

  test('sync returns SyncResult.offlineFirstBoot when no internet and db is empty', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => false);
    when(mockDb.database).thenAnswer((_) async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
      });
      openedDb = db;
      return db;
    });

    final result = await service.sync();
    expect(result, SyncResult.offlineFirstBoot);
  });

  test('sync returns SyncResult.offlineWithData when no internet and db has sync_meta row', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => false);
    when(mockDb.database).thenAnswer((_) async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await db.insert('sync_meta', {'id': 1, 'manifest_version': 1, 'last_sync_at': 0});
      });
      openedDb = db;
      return db;
    });

    final result = await service.sync();
    expect(result, SyncResult.offlineWithData);
  });

  test('sync returns SyncResult.upToDate when manifest version matches local', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);
    when(mockRemote.fetchManifest()).thenAnswer((_) async => ContentManifest(
          version: 3,
          updatedAt: '2026-05-27T12:00:00Z',
          lessons: [],
        ));
    when(mockDb.database).thenAnswer((_) async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await db.insert('sync_meta', {'id': 1, 'manifest_version': 3, 'last_sync_at': 0});
      });
      openedDb = db;
      return db;
    });

    final result = await service.sync();
    expect(result, SyncResult.upToDate);
  });

  test('sync returns SyncResult.offlineWithData when manifest fetch fails but db has data', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);
    when(mockRemote.fetchManifest()).thenThrow(RemoteContentException('timeout'));
    when(mockDb.database).thenAnswer((_) async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await db.insert('sync_meta', {'id': 1, 'manifest_version': 1, 'last_sync_at': 0});
      });
      openedDb = db;
      return db;
    });

    final result = await service.sync();
    expect(result, SyncResult.offlineWithData);
  });

  test('lesson removed from manifest is deleted from local db on sync', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);
    // Manifest now has only lesson 2 — lesson 1 was unpublished
    when(mockRemote.fetchManifest()).thenAnswer((_) async => ContentManifest(
          version: 3,
          updatedAt: '2026-05-30T00:00:00Z',
          lessons: [
            ManifestLesson(
              id: 2,
              title: 'Lesson 2',
              pdf: ManifestFileEntry(active: 'lessons/2/lesson_v1.pdf', checksum: 'ccc', history: []),
              audio: null,
            ),
          ],
        ));
    when(mockRemote.downloadFile(remotePath: anyNamed('remotePath'), localPath: anyNamed('localPath')))
        .thenAnswer((_) async {});

    when(mockDb.database).thenAnswer((_) async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await db.insert('sync_meta', {'id': 1, 'manifest_version': 2, 'last_sync_at': 0});
        await db.execute('''
          CREATE TABLE lessons (
            id INTEGER PRIMARY KEY, title TEXT NOT NULL,
            pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL,
            audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT,
            synced_at INTEGER NOT NULL
          )
        ''');
        // Lesson 1 exists locally but is no longer in the manifest
        await db.insert('lessons', {
          'id': 1, 'title': 'Lesson 1',
          'pdf_local_path': 'betelapp/lessons/1/lesson.pdf', 'pdf_checksum': 'aaa',
          'synced_at': 0,
        });
        await db.insert('lessons', {
          'id': 2, 'title': 'Lesson 2',
          'pdf_local_path': 'betelapp/lessons/2/lesson.pdf', 'pdf_checksum': 'ccc',
          'synced_at': 0,
        });
      });
      openedDb = db;
      return db;
    });

    await service.sync(getDocsDir: () async => '/tmp/test-docs');

    final remaining = await openedDb!.query('lessons');
    expect(remaining.length, 1);
    expect(remaining.first['id'], 2);
  });

  test('lesson still in manifest is preserved during sync', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);
    when(mockRemote.fetchManifest()).thenAnswer((_) async => ContentManifest(
          version: 3,
          updatedAt: '2026-05-30T00:00:00Z',
          lessons: [
            ManifestLesson(
              id: 1,
              title: 'Lesson 1',
              pdf: ManifestFileEntry(active: 'lessons/1/lesson_v1.pdf', checksum: 'aaa', history: []),
              audio: null,
            ),
          ],
        ));

    when(mockDb.database).thenAnswer((_) async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await db.insert('sync_meta', {'id': 1, 'manifest_version': 2, 'last_sync_at': 0});
        await db.execute('''
          CREATE TABLE lessons (
            id INTEGER PRIMARY KEY, title TEXT NOT NULL,
            pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL,
            audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT,
            synced_at INTEGER NOT NULL
          )
        ''');
        await db.insert('lessons', {
          'id': 1, 'title': 'Lesson 1',
          'pdf_local_path': 'betelapp/lessons/1/lesson.pdf', 'pdf_checksum': 'aaa',
          'synced_at': 0,
        });
      });
      openedDb = db;
      return db;
    });

    await service.sync(getDocsDir: () async => '/tmp/test-docs');

    final remaining = await openedDb!.query('lessons');
    expect(remaining.length, 1);
    expect(remaining.first['id'], 1);
  });

  test('sync persists Q&As from manifest to card_progress for new lessons', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);

    final manifest = ContentManifest(
      version: 5,
      updatedAt: '2026-06-02T00:00:00Z',
      lessons: [
        ManifestLesson(
          id: 1,
          title: 'Lição 1',
          pdf: ManifestFileEntry(active: 'lessons/1/lesson_v1.pdf', checksum: 'abc', history: []),
          audio: null,
          questions: [
            ManifestQuestion(id: 10, question: 'Pergunta 1?', answer: 'Resposta 1.'),
            ManifestQuestion(id: 11, question: 'Pergunta 2?', answer: 'Resposta 2.'),
          ],
        ),
      ],
    );

    when(mockRemote.fetchManifest()).thenAnswer((_) async => manifest);
    when(mockRemote.downloadFile(remotePath: anyNamed('remotePath'), localPath: anyNamed('localPath')))
        .thenAnswer((_) async {});

    Database? db;
    when(mockDb.database).thenAnswer((_) async {
      if (db != null) return db!;
      db = await openDatabase(inMemoryDatabasePath, version: 3, onCreate: (database, _) async {
        await database.execute('CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await database.execute('CREATE TABLE lessons (id INTEGER PRIMARY KEY, title TEXT NOT NULL, audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT, pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL, synced_at INTEGER NOT NULL)');
        await database.execute('CREATE TABLE card_progress (question_id INTEGER PRIMARY KEY, lesson_id INTEGER NOT NULL, bucket INTEGER NOT NULL DEFAULT 1, last_reviewed_at TEXT, next_review_at TEXT NOT NULL, question_text TEXT, answer_text TEXT)');
      });
      openedDb = db;
      return db!;
    });

    await service.sync(getDocsDir: () async => '/tmp');

    final database = await mockDb.database;
    final rows = await database.query('card_progress');
    expect(rows.length, 2);
    expect(rows.any((r) => r['question_id'] == 10 && r['lesson_id'] == 1), true);
    expect(rows.any((r) => r['question_id'] == 11 && r['lesson_id'] == 1), true);
    expect(rows.every((r) => r['bucket'] == 1), true);
  });

  test('sync removes card_progress entries for Q&As removed from manifest', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);

    final manifest = ContentManifest(
      version: 6,
      updatedAt: '2026-06-02T00:00:00Z',
      lessons: [
        ManifestLesson(
          id: 1,
          title: 'Lição 1',
          pdf: ManifestFileEntry(active: 'lessons/1/lesson_v1.pdf', checksum: 'xyz', history: []),
          audio: null,
          questions: [
            ManifestQuestion(id: 10, question: 'Pergunta 1?', answer: 'Resposta 1.'),
            // question 11 was removed from the manifest
          ],
        ),
      ],
    );

    when(mockRemote.fetchManifest()).thenAnswer((_) async => manifest);
    when(mockRemote.downloadFile(remotePath: anyNamed('remotePath'), localPath: anyNamed('localPath')))
        .thenAnswer((_) async {});

    Database? db;
    when(mockDb.database).thenAnswer((_) async {
      if (db != null) return db!;
      db = await openDatabase(inMemoryDatabasePath, version: 3, onCreate: (database, _) async {
        await database.execute('CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await database.execute('CREATE TABLE lessons (id INTEGER PRIMARY KEY, title TEXT NOT NULL, audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT, pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL, synced_at INTEGER NOT NULL)');
        await database.execute('CREATE TABLE card_progress (question_id INTEGER PRIMARY KEY, lesson_id INTEGER NOT NULL, bucket INTEGER NOT NULL DEFAULT 1, last_reviewed_at TEXT, next_review_at TEXT NOT NULL, question_text TEXT, answer_text TEXT)');
      });
      // Pre-populate card_progress with TWO questions (11 is no longer in manifest)
      await db!.insert('card_progress', {'question_id': 10, 'lesson_id': 1, 'bucket': 3, 'next_review_at': '2026-06-10T00:00:00.000'});
      await db!.insert('card_progress', {'question_id': 11, 'lesson_id': 1, 'bucket': 2, 'next_review_at': '2026-06-08T00:00:00.000'});
      openedDb = db;
      return db!;
    });

    await service.sync(getDocsDir: () async => '/tmp');

    final database = await mockDb.database;
    final rows = await database.query('card_progress');
    expect(rows.length, 1);
    expect(rows.first['question_id'], 10);
    expect(rows.first['bucket'], 3, reason: 'existing progress should be preserved');
  });
}
