import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:betelapp/core/connectivity_service.dart';
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/models/flashcard.dart';
import 'package:betelapp/data/models/manifest.dart';
import 'package:betelapp/data/repositories/review_repository_impl.dart';
import 'package:betelapp/data/services/remote_content_service.dart';

enum SyncResult {
  offlineFirstBoot,
  offlineWithData,
  upToDate,
  updated,
  error,
}

class SyncProgress {
  final int current;
  final int total;
  final String lessonTitle;
  SyncProgress(this.current, this.total, this.lessonTitle);
}

class ContentSyncService {
  final RemoteContentService _remote;
  final ConnectivityService _connectivity;
  final DatabaseHelper _dbHelper;

  ContentSyncService({
    required RemoteContentService remote,
    required ConnectivityService connectivity,
    required DatabaseHelper dbHelper,
  })  : _remote = remote,
        _connectivity = connectivity,
        _dbHelper = dbHelper;

  Future<SyncResult> sync({
    void Function(SyncProgress)? onProgress,
    Future<String> Function()? getDocsDir,
  }) async {
    final db = await _dbHelper.database;

    final connected = await _connectivity.isConnected();
    if (!connected) {
      final meta = await db.query('sync_meta', limit: 1);
      return meta.isEmpty ? SyncResult.offlineFirstBoot : SyncResult.offlineWithData;
    }

    late ContentManifest manifest;
    try {
      manifest = await _remote.fetchManifest();
    } catch (_) {
      final meta = await db.query('sync_meta', limit: 1);
      return meta.isEmpty ? SyncResult.offlineFirstBoot : SyncResult.offlineWithData;
    }

    final meta = await db.query('sync_meta', limit: 1);
    final localVersion = meta.isEmpty ? -1 : meta.first['manifest_version'] as int;
    if (localVersion == manifest.version) return SyncResult.upToDate;

    // Remove lessons that are no longer in the manifest
    final manifestIds = manifest.lessons.map((l) => l.id).toSet();
    final localLessons = await db.query('lessons', columns: ['id']);
    for (final row in localLessons) {
      final localId = row['id'] as int;
      if (!manifestIds.contains(localId)) {
        await db.delete('lessons', where: 'id = ?', whereArgs: [localId]);
      }
    }

    final lessonsToDownload = <ManifestLesson>[];
    for (final lesson in manifest.lessons) {
      final existing = await db.query('lessons',
          where: 'id = ?', whereArgs: [lesson.id], limit: 1);
      if (existing.isEmpty) {
        lessonsToDownload.add(lesson);
      } else {
        final row = existing.first;
        if (row['pdf_checksum'] != lesson.pdf.checksum ||
            row['audio_checksum'] != lesson.audio?.checksum) {
          lessonsToDownload.add(lesson);
        }
      }
    }

    if (lessonsToDownload.isEmpty) {
      await db.insert(
        'sync_meta',
        {
          'id': 1,
          'manifest_version': manifest.version,
          'last_sync_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
      return SyncResult.updated;
    }

    final resolvedGetDocsDir = getDocsDir ?? () async => (await getApplicationDocumentsDirectory()).path;
    final docsDirPath = await resolvedGetDocsDir();

    int current = 0;
    for (final lesson in lessonsToDownload) {
      current++;
      onProgress?.call(SyncProgress(current, lessonsToDownload.length, lesson.title));

      final lessonDir = Directory(
          p.join(docsDirPath, 'betelapp', 'lessons', '${lesson.id}'));
      await lessonDir.create(recursive: true);

      final pdfLocalPath =
          p.join('betelapp', 'lessons', '${lesson.id}', 'lesson.pdf');
      await _remote.downloadFile(
        remotePath: lesson.pdf.active,
        localPath: p.join(docsDirPath, pdfLocalPath),
      );

      String? audioLocalPath;
      String? audioExt;
      if (lesson.audio != null) {
        audioExt = lesson.audio!.ext;
        audioLocalPath =
            p.join('betelapp', 'lessons', '${lesson.id}', 'audio.$audioExt');
        await _remote.downloadFile(
          remotePath: lesson.audio!.active,
          localPath: p.join(docsDirPath, audioLocalPath),
        );
      }

      await db.insert(
        'lessons',
        {
          'id': lesson.id,
          'title': lesson.title,
          'pdf_local_path': pdfLocalPath,
          'pdf_checksum': lesson.pdf.checksum,
          'audio_local_path': audioLocalPath,
          'audio_ext': audioExt,
          'audio_checksum': lesson.audio?.checksum,
          'synced_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );

      // Persist Q&As to card_progress (insert-only, preserves existing Leitner progress)
      final reviewRepo = ReviewRepositoryImpl(_dbHelper);
      final flashcards = lesson.questions
          .map((q) => Flashcard(
                id: q.id,
                lessonId: lesson.id,
                question: q.question,
                answer: q.answer,
              ))
          .toList();
      await reviewRepo.upsertCards(flashcards);

      // Remove card_progress for Q&As no longer in the manifest
      final manifestQuestionIds = lesson.questions.map((q) => q.id).toSet();
      final existingRows = await db.query(
        'card_progress',
        columns: ['question_id'],
        where: 'lesson_id = ?',
        whereArgs: [lesson.id],
      );
      final removedIds = existingRows
          .map((r) => r['question_id'] as int)
          .where((id) => !manifestQuestionIds.contains(id))
          .toList();
      if (removedIds.isNotEmpty) {
        await reviewRepo.deleteCardsForQuestionIds(removedIds);
      }
    }

    await db.insert(
      'sync_meta',
      {
        'id': 1,
        'manifest_version': manifest.version,
        'last_sync_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    return SyncResult.updated;
  }
}
