import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/domain/entities/favorite.dart';
import 'package:betelsas/domain/repositories/favorites_repository.dart';
import 'package:sqflite/sqflite.dart';


class FavoritesRepositoryImpl implements FavoritesRepository {
  final DatabaseHelper _dbHelper;

  FavoritesRepositoryImpl(this._dbHelper);

  @override
  Future<List<Favorite>> getFavorites() async {
    final db = await _dbHelper.database;
    final results = await db.query('favorites');
    return results.map((map) => Favorite.fromMap(map)).toList();
  }

  @override
  Future<void> addFavorite(String type, String itemId) async {
    final db = await _dbHelper.database;
    final exists = await isFavorite(type, itemId);
    if (!exists) {
      await db.insert('favorites', {
        'id': '${type}_$itemId',
        'type': type,
        'item_id': itemId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  @override
  Future<void> removeFavorite(String type, String itemId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'favorites',
      where: 'type = ? AND item_id = ?',
      whereArgs: [type, itemId],
    );
  }

  @override
  Future<bool> isFavorite(String type, String itemId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'favorites',
      where: 'type = ? AND item_id = ?',
      whereArgs: [type, itemId],
    );
    return result.isNotEmpty;
  }
}
