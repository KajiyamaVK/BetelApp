import 'package:betelsas/domain/entities/favorite.dart';

abstract class FavoritesRepository {
  Future<List<Favorite>> getFavorites();
  Future<void> addFavorite(String type, String itemId);
  Future<void> removeFavorite(String type, String itemId);
  Future<bool> isFavorite(String type, String itemId);
}
