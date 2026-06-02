import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/domain/repositories/favorites_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite/sqflite.dart';

@GenerateMocks([
  DatabaseHelper,
  Database,
  FavoritesRepository,
])
void main() {}
