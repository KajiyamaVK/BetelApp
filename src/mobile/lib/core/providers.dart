import 'package:file/file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/data/repositories/content_repository.dart';
import 'package:betelsas/data/repositories/flashcard_repository.dart';

import 'package:betelsas/data/repositories/favorites_repository_impl.dart';
import 'package:betelsas/domain/repositories/favorites_repository.dart';

// Core
final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper());

// Repositories
final contentRepositoryProvider = Provider<ContentRepository>((ref) => ContentRepository());

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return FavoritesRepositoryImpl(dbHelper);
});

final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  final contentRepo = ref.watch(contentRepositoryProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  return FlashcardRepository(contentRepo, dbHelper);
});
