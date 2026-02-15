import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/domain/repositories/favorites_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite/sqflite.dart';

@GenerateMocks([
  DatabaseHelper,
  Database,
  FavoritesRepository,
])
void main() {}
