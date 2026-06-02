import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/models/lesson.dart';

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
}
