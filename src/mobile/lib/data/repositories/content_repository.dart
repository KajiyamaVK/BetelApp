import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/models/content.dart';
import 'package:betelapp/data/models/lesson.dart';
import 'package:betelapp/data/models/song.dart';
import 'package:path_provider/path_provider.dart';

class ContentRepository {
  final DatabaseHelper _dbHelper;

  ContentRepository({required DatabaseHelper dbHelper}) : _dbHelper = dbHelper;

  Future<List<Lesson>> loadLessons() async {
    final db = await _dbHelper.database;
    final rows = await db.query('lessons', orderBy: 'id ASC');
    return rows.map(Lesson.fromMap).toList();
  }

  Future<List<Lesson>> loadLessonsWithAudio() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'lessons',
      where: 'audio_local_path IS NOT NULL',
      orderBy: 'id ASC',
    );
    return rows.map(Lesson.fromMap).toList();
  }

  Future<List<Content>> loadContents() async {
    final db = await _dbHelper.database;
    final rows = await db.query('contents', orderBy: 'id ASC');
    return rows.map(Content.fromMap).toList();
  }

  Future<List<Song>> loadSongsFromLessons() async {
    final dir = await getApplicationDocumentsDirectory();
    final lessons = await loadLessonsWithAudio();
    return lessons
        .map((l) => Song(
              id: l.id.toString(),
              title: l.title,
              artist: 'Betel',
              audioUrl: '${dir.path}/${l.localAudioPath!}',
            ))
        .toList();
  }

  Future<Content?> loadContentBySlug(String slug) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'contents',
      where: 'slug = ?',
      whereArgs: [slug],
      limit: 1,
    );
    return rows.isEmpty ? null : Content.fromMap(rows.first);
  }
}
