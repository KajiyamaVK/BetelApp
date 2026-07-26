import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/core/connectivity_service.dart';
import 'package:betelapp/data/services/remote_content_service.dart';
import 'package:betelapp/data/services/content_sync_service.dart';
import 'package:betelapp/data/models/manifest.dart';
import 'package:betelapp/data/repositories/content_repository.dart';
import 'package:betelapp/data/repositories/review_repository_impl.dart';

@GenerateMocks([RemoteContentService, ConnectivityService, DatabaseHelper])
import 'content_sync_service_test.mocks.dart';

Future<Database> _openFullSchema() => openDatabase(
      inMemoryDatabasePath,
      version: 6,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE sync_meta (id INTEGER PRIMARY KEY, manifest_version INTEGER, last_sync_at INTEGER)');
        await db.execute('CREATE TABLE lessons (id INTEGER PRIMARY KEY, title TEXT NOT NULL, audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT, pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL, synced_at INTEGER NOT NULL, question_count INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE card_progress (question_id INTEGER PRIMARY KEY, lesson_id INTEGER NOT NULL, bucket INTEGER NOT NULL DEFAULT 1, last_reviewed_at TEXT, next_review_at TEXT NOT NULL, question_text TEXT, answer_text TEXT)');
        await db.execute('CREATE TABLE review_active (lesson_id INTEGER PRIMARY KEY, active INTEGER NOT NULL DEFAULT 1)');
        await db.execute("CREATE TABLE contents (id INTEGER PRIMARY KEY, slug TEXT NOT NULL UNIQUE, title TEXT NOT NULL, type TEXT NOT NULL, youtube_url TEXT, html TEXT, pages_html TEXT, display_location TEXT NOT NULL DEFAULT 'HOME', synced_at INTEGER NOT NULL)");
      },
    );

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
      reviewRepo: ReviewRepositoryImpl(mockDb),
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
              pdf: ManifestFileEntry(active: 'lessons/2/lesson_v1.pdf', checksum: 'ccc'),
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
            synced_at INTEGER NOT NULL, question_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE TABLE contents (id INTEGER PRIMARY KEY, slug TEXT NOT NULL UNIQUE, title TEXT NOT NULL, type TEXT NOT NULL, youtube_url TEXT, html TEXT, synced_at INTEGER NOT NULL)');
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
              pdf: ManifestFileEntry(active: 'lessons/1/lesson_v1.pdf', checksum: 'aaa'),
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
            synced_at INTEGER NOT NULL, question_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE TABLE contents (id INTEGER PRIMARY KEY, slug TEXT NOT NULL UNIQUE, title TEXT NOT NULL, type TEXT NOT NULL, youtube_url TEXT, html TEXT, synced_at INTEGER NOT NULL)');
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
          pdf: ManifestFileEntry(active: 'lessons/1/lesson_v1.pdf', checksum: 'abc'),
          audio: null,
          questions: [
            const ManifestQuestion(id: 10, question: 'Pergunta 1?', answer: 'Resposta 1.'),
            const ManifestQuestion(id: 11, question: 'Pergunta 2?', answer: 'Resposta 2.'),
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
      db = await _openFullSchema();
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

  // Review toggle is OFF by default — sync must NOT auto-activate review for new lessons.
  test('sync does NOT activate review for new lessons that have Q&A', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);

    final manifest = ContentManifest(
      version: 7,
      updatedAt: '2026-06-03T00:00:00Z',
      lessons: [
        ManifestLesson(
          id: 1,
          title: 'Lição com Q&A',
          pdf: ManifestFileEntry(active: 'lessons/1/lesson_v1.pdf', checksum: 'abc'),
          audio: null,
          questions: [
            const ManifestQuestion(id: 20, question: 'Q?', answer: 'A.'),
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
      db = await _openFullSchema();
      openedDb = db;
      return db!;
    });

    await service.sync(getDocsDir: () async => '/tmp');

    final database = await mockDb.database;
    final rows = await database.query('review_active', where: 'lesson_id = ?', whereArgs: [1]);
    expect(rows.isEmpty, true,
        reason: 'sync must not insert a review_active row — toggle starts OFF by default');
  });

  // Regression: re-syncing a lesson must not override the user's explicit deactivation.
  test('sync does NOT override explicit review deactivation on re-sync', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);

    final manifest = ContentManifest(
      version: 8,
      updatedAt: '2026-06-03T00:00:00Z',
      lessons: [
        ManifestLesson(
          id: 1,
          title: 'Lição com Q&A',
          pdf: ManifestFileEntry(active: 'lessons/1/lesson_v2.pdf', checksum: 'new'),
          audio: null,
          questions: [
            const ManifestQuestion(id: 20, question: 'Q?', answer: 'A.'),
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
      db = await _openFullSchema();
      // User previously deactivated review for lesson 1
      await db!.insert('review_active', {'lesson_id': 1, 'active': 0});
      // Old checksum forces re-download
      await db!.insert('sync_meta', {'id': 1, 'manifest_version': 7, 'last_sync_at': 0});
      await db!.insert('lessons', {
        'id': 1, 'title': 'Lição com Q&A',
        'pdf_local_path': 'lessons/1/lesson_v1.pdf', 'pdf_checksum': 'old',
        'synced_at': 0, 'question_count': 1,
      });
      openedDb = db;
      return db!;
    });

    await service.sync(getDocsDir: () async => '/tmp');

    final database = await mockDb.database;
    final rows = await database.query('review_active', where: 'lesson_id = ?', whereArgs: [1]);
    expect(rows.first['active'], 0,
        reason: 'user deactivated review — re-sync must not override that choice');
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
          pdf: ManifestFileEntry(active: 'lessons/1/lesson_v1.pdf', checksum: 'xyz'),
          audio: null,
          questions: [
            const ManifestQuestion(id: 10, question: 'Pergunta 1?', answer: 'Resposta 1.'),
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
      db = await _openFullSchema();
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

  // Regression: a title-only change in the manifest must update the local lesson title.
  // Previously, sync only checked checksum and question_count — title changes were silently ignored.
  test('sync updates title in local db when only the title changed in the manifest', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);

    final manifest = ContentManifest(
      version: 5,
      updatedAt: '2026-06-05T00:00:00Z',
      lessons: [
        ManifestLesson(
          id: 1,
          title: 'Título Corrigido',
          pdf: ManifestFileEntry(active: 'lessons/1/lesson_v1.pdf', checksum: 'abc'),
          audio: null,
          questions: [],
        ),
      ],
    );

    when(mockRemote.fetchManifest()).thenAnswer((_) async => manifest);

    Database? db;
    when(mockDb.database).thenAnswer((_) async {
      if (db != null) return db!;
      db = await _openFullSchema();
      await db!.insert('sync_meta', {'id': 1, 'manifest_version': 4, 'last_sync_at': 0});
      await db!.insert('lessons', {
        'id': 1, 'title': 'Título Antigo',
        'pdf_local_path': 'betelapp/lessons/1/lesson.pdf', 'pdf_checksum': 'abc',
        'synced_at': 0, 'question_count': 0,
      });
      openedDb = db;
      return db!;
    });

    await service.sync(getDocsDir: () async => '/tmp');

    final database = await mockDb.database;
    final rows = await database.query('lessons', where: 'id = ?', whereArgs: [1]);
    expect(rows.first['title'], 'Título Corrigido',
        reason: 'title change in manifest must be reflected in local db after sync');
  });

  // Regression: Q&As added to a published lesson must appear in the app even when
  // the lesson's file checksums did not change (add→delete→re-add cycle on portal).
  test('sync upserts Q&As for existing lessons whose questions changed in manifest', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);

    // Manifest version bumped because a Q&A was added — but PDF checksum unchanged
    final manifest = ContentManifest(
      version: 10,
      updatedAt: '2026-06-03T00:00:00Z',
      lessons: [
        ManifestLesson(
          id: 24,
          title: 'Lição 24',
          pdf: ManifestFileEntry(active: 'lessons/24/lesson_v1.pdf', checksum: 'same'),
          audio: null,
          questions: [
            const ManifestQuestion(id: 4, question: 'Qual a pergunta 24?', answer: 'Resposta 24'),
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
      db = await _openFullSchema();
      // Lesson 24 already exists locally with the SAME checksum — only Q&As changed
      await db!.insert('sync_meta', {'id': 1, 'manifest_version': 9, 'last_sync_at': 0});
      await db!.insert('lessons', {
        'id': 24, 'title': 'Lição 24',
        'pdf_local_path': 'betelapp/lessons/24/lesson.pdf', 'pdf_checksum': 'same',
        'synced_at': 0, 'question_count': 0,
      });
      openedDb = db;
      return db!;
    });

    await service.sync(getDocsDir: () async => '/tmp');

    final database = await mockDb.database;
    final rows = await database.query('card_progress', where: 'lesson_id = ?', whereArgs: [24]);
    expect(rows.length, 1,
        reason: 'Q&A added to existing lesson must appear in card_progress even when file checksums unchanged');
    expect(rows.first['question_id'], 4);
  });

  test('sync inserts contents from manifest into local db', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);

    final manifest = ContentManifest(
      version: 5,
      updatedAt: '2026-06-13T00:00:00Z',
      lessons: [],
      contents: [
        ManifestContent(id: 1, slug: 'welcome', title: 'Bem-vindo', type: 'VIDEO', youtubeUrl: 'https://youtube.com/watch?v=abc'),
        ManifestContent(id: 2, slug: 'about', title: 'Sobre', type: 'TEXT', html: '<p>Hello</p>'),
      ],
    );

    when(mockRemote.fetchManifest()).thenAnswer((_) async => manifest);

    Database? db;
    when(mockDb.database).thenAnswer((_) async {
      if (db != null) return db!;
      db = await _openFullSchema();
      openedDb = db;
      return db!;
    });

    final result = await service.sync(getDocsDir: () async => '/tmp');
    expect(result, SyncResult.updated);

    final database = await mockDb.database;
    final rows = await database.query('contents', orderBy: 'id ASC');
    expect(rows.length, 2);
    expect(rows[0]['slug'], 'welcome');
    expect(rows[0]['type'], 'VIDEO');
    expect(rows[0]['youtube_url'], 'https://youtube.com/watch?v=abc');
    expect(rows[1]['slug'], 'about');
    expect(rows[1]['type'], 'TEXT');
    expect(rows[1]['html'], '<p>Hello</p>');
  });

  test('sync removes contents no longer in manifest', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);

    // Manifest no longer has content id=1
    final manifest = ContentManifest(
      version: 6,
      updatedAt: '2026-06-13T00:00:00Z',
      lessons: [],
      contents: [
        ManifestContent(id: 2, slug: 'about', title: 'Sobre', type: 'TEXT', html: '<p>Hello</p>'),
      ],
    );

    when(mockRemote.fetchManifest()).thenAnswer((_) async => manifest);

    Database? db;
    when(mockDb.database).thenAnswer((_) async {
      if (db != null) return db!;
      db = await _openFullSchema();
      await db!.insert('sync_meta', {'id': 1, 'manifest_version': 5, 'last_sync_at': 0});
      // Content id=1 exists locally but was unpublished from the manifest
      await db!.insert('contents', {
        'id': 1, 'slug': 'welcome', 'title': 'Bem-vindo', 'type': 'VIDEO',
        'youtube_url': 'https://youtube.com/watch?v=abc', 'synced_at': 0,
      });
      await db!.insert('contents', {
        'id': 2, 'slug': 'about', 'title': 'Sobre', 'type': 'TEXT',
        'html': '<p>Hello</p>', 'synced_at': 0,
      });
      openedDb = db;
      return db!;
    });

    await service.sync(getDocsDir: () async => '/tmp');

    final database = await mockDb.database;
    final rows = await database.query('contents');
    expect(rows.length, 1);
    expect(rows.first['id'], 2);
  });

  test('sync handles manifest with no contents field (backward compat)', () async {
    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);

    // Old manifest without contents field — ContentManifest defaults to empty list
    final manifest = ContentManifest(
      version: 2,
      updatedAt: '2026-05-27T00:00:00Z',
      lessons: [],
    );

    when(mockRemote.fetchManifest()).thenAnswer((_) async => manifest);

    Database? db;
    when(mockDb.database).thenAnswer((_) async {
      if (db != null) return db!;
      db = await _openFullSchema();
      openedDb = db;
      return db!;
    });

    final result = await service.sync(getDocsDir: () async => '/tmp');
    expect(result, SyncResult.updated);

    final database = await mockDb.database;
    final rows = await database.query('contents');
    expect(rows, isEmpty);
  });

  // Regression: upgrading the local DB to v6 backfills display_location with the
  // literal default 'HOME' for every existing content row. When the manifest version
  // is unchanged since the last sync (the app already synced v144 before the update),
  // the version gate in sync() skips content re-population — leaving help content
  // stuck at 'HOME' and unreachable by its HELP_* location, so the tab "?" buttons
  // open nothing. The migration must invalidate the sync checkpoint so the next sync
  // re-inserts contents with their real display_location.
  test('help content is reachable after v5->v6 upgrade even when manifest version is unchanged', () async {
    const tmpPath = '/tmp/betel_display_location_resync_test.db';
    await databaseFactoryFfi.deleteDatabase(tmpPath);

    // Seed a v5 database: contents predate the display_location column, and the app
    // had already synced manifest version 144 before the user updated the app.
    final seedDb = await databaseFactoryFfi.openDatabase(
      tmpPath,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, _) async {
          await db.execute(
              'CREATE TABLE sync_meta (id INTEGER PRIMARY KEY DEFAULT 1, manifest_version INTEGER NOT NULL, last_sync_at INTEGER NOT NULL)');
          await db.execute(
              'CREATE TABLE lessons (id INTEGER PRIMARY KEY, title TEXT NOT NULL, audio_local_path TEXT, audio_ext TEXT, audio_checksum TEXT, pdf_local_path TEXT NOT NULL, pdf_checksum TEXT NOT NULL, synced_at INTEGER NOT NULL, question_count INTEGER NOT NULL DEFAULT 0)');
          await db.execute(
              'CREATE TABLE card_progress (question_id INTEGER PRIMARY KEY, lesson_id INTEGER NOT NULL, bucket INTEGER NOT NULL DEFAULT 1, last_reviewed_at TEXT, next_review_at TEXT NOT NULL, question_text TEXT, answer_text TEXT)');
          await db.execute(
              'CREATE TABLE review_active (lesson_id INTEGER PRIMARY KEY, active INTEGER NOT NULL DEFAULT 0)');
          await db.execute(
              'CREATE TABLE contents (id INTEGER PRIMARY KEY, slug TEXT NOT NULL UNIQUE, title TEXT NOT NULL, type TEXT NOT NULL, youtube_url TEXT, html TEXT, pages_html TEXT, synced_at INTEGER NOT NULL)');
          await db.insert('sync_meta', {'id': 1, 'manifest_version': 144, 'last_sync_at': 0});
          await db.insert('contents', {
            'id': 9, 'slug': 'devocionais', 'title': 'Ajuda Devocionais',
            'type': 'TEXT', 'html': '<p>ajuda</p>', 'synced_at': 0,
          });
        },
      ),
    );
    await seedDb.close();

    // Reopen through the real DatabaseHelper so _onUpgrade (v5->v6) runs.
    DatabaseHelper.resetForTesting(dbPath: tmpPath);
    final dbHelper = DatabaseHelper();

    when(mockConnectivity.isConnected()).thenAnswer((_) async => true);
    when(mockConnectivity.isMobileData()).thenAnswer((_) async => false);
    // Manifest version is UNCHANGED (144) but now carries the real display_location.
    when(mockRemote.fetchManifest()).thenAnswer((_) async => ContentManifest(
          version: 144,
          updatedAt: '2026-07-24T15:39:58Z',
          lessons: [],
          contents: [
            ManifestContent(
              id: 9,
              slug: 'devocionais',
              title: 'Ajuda Devocionais',
              type: 'TEXT',
              html: '<p>ajuda</p>',
              displayLocation: 'HELP_DEVOCIONAIS',
            ),
          ],
        ));

    final realService = ContentSyncService(
      remote: mockRemote,
      connectivity: mockConnectivity,
      dbHelper: dbHelper,
      reviewRepo: ReviewRepositoryImpl(dbHelper),
    );

    await realService.sync(getDocsDir: () async => '/tmp');

    final repository = ContentRepository(dbHelper: dbHelper);
    final content = await repository.loadContentByLocation('HELP_DEVOCIONAIS');
    expect(content, isNotNull,
        reason: 'após o upgrade, o conteúdo de ajuda deve ser alcançável por sua localização mesmo com a versão do manifest inalterada');
    expect(content!.displayLocation, 'HELP_DEVOCIONAIS');

    final db = await dbHelper.database;
    await db.close();
    DatabaseHelper.resetForTesting(dbPath: inMemoryDatabasePath);
    await databaseFactoryFfi.deleteDatabase(tmpPath);
  });
}
