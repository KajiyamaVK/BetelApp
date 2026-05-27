import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betelsas/core/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    DatabaseHelper.resetForTesting();
  });

  test('database version is 2', () async {
    final db = await DatabaseHelper().database;
    expect(await db.getVersion(), 2);
  });

  test('lessons table exists with correct columns', () async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery("PRAGMA table_info(lessons)");
    final columns = result.map((r) => r['name'] as String).toSet();
    expect(columns, containsAll([
      'id', 'title', 'audio_local_path', 'audio_ext',
      'audio_checksum', 'pdf_local_path', 'pdf_checksum', 'synced_at'
    ]));
  });

  test('sync_meta table exists with correct columns', () async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery("PRAGMA table_info(sync_meta)");
    final columns = result.map((r) => r['name'] as String).toSet();
    expect(columns, containsAll(['id', 'manifest_version', 'last_sync_at']));
  });
}
