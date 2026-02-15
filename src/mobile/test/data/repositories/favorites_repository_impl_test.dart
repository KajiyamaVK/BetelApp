import 'package:betelsas/data/repositories/favorites_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/test_helper.mocks.dart';

void main() {
  late MockDatabaseHelper mockDbHelper;
  late MockDatabase mockDatabase;
  late FavoritesRepositoryImpl repository;

  setUp(() {
    mockDbHelper = MockDatabaseHelper();
    mockDatabase = MockDatabase();
    
    // Mock database getter
    when(mockDbHelper.database).thenAnswer((_) async => mockDatabase);
    
    repository = FavoritesRepositoryImpl(mockDbHelper);
  });

  group('FavoritesRepositoryImpl Mock Tests', () {
    test('getFavorites returns list of favorites', () async {
      final mockData = [
        {
          'id': 'lesson_1',
          'type': 'lesson',
          'item_id': '1',
          'added_at': DateTime.now().millisecondsSinceEpoch
        }
      ];

      when(mockDatabase.query('favorites')).thenAnswer((_) async => mockData);

      final result = await repository.getFavorites();

      expect(result.length, 1);
      expect(result.first.itemId, '1');
      verify(mockDatabase.query('favorites')).called(1);
    });

    test('addFavorite inserts if not exists', () async {
      // Mock isFavorite check (returning empty list means not favorite)
      when(mockDatabase.query(
        'favorites',
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
      )).thenAnswer((_) async => []);

      when(mockDatabase.insert('favorites', any)).thenAnswer((_) async => 1);

      await repository.addFavorite('lesson', '1');

      verify(mockDatabase.insert('favorites', any)).called(1);
    });

    test('removeFavorite deletes item', () async {
      when(mockDatabase.delete(
        'favorites',
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
      )).thenAnswer((_) async => 1);

      await repository.removeFavorite('lesson', '1');

      verify(mockDatabase.delete(
        'favorites',
        where: anyNamed('where'),
        whereArgs: anyNamed('whereArgs'),
      )).called(1);
    });
  });
}
