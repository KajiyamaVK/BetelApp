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
}
