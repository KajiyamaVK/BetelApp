import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:betelsas/core/connectivity_service.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/data/models/manifest.dart';
import 'package:betelsas/data/services/remote_content_service.dart';

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

    final docsDir = await getApplicationDocumentsDirectory();

    int current = 0;
    for (final lesson in lessonsToDownload) {
      current++;
      onProgress?.call(SyncProgress(current, lessonsToDownload.length, lesson.title));

      final lessonDir = Directory(
          p.join(docsDir.path, 'betelsas', 'lessons', '${lesson.id}'));
      await lessonDir.create(recursive: true);

      final pdfLocalPath =
          p.join('betelsas', 'lessons', '${lesson.id}', 'lesson.pdf');
      await _remote.downloadFile(
        remotePath: lesson.pdf.active,
        localPath: p.join(docsDir.path, pdfLocalPath),
      );

      String? audioLocalPath;
      String? audioExt;
      if (lesson.audio != null) {
        audioExt = lesson.audio!.ext;
        audioLocalPath =
            p.join('betelsas', 'lessons', '${lesson.id}', 'audio.$audioExt');
        await _remote.downloadFile(
          remotePath: lesson.audio!.active,
          localPath: p.join(docsDir.path, audioLocalPath),
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
