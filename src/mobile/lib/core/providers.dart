import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelsas/core/connectivity_service.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/data/repositories/content_repository.dart';
import 'package:betelsas/data/repositories/favorites_repository_impl.dart';
import 'package:betelsas/data/services/content_sync_service.dart';
import 'package:betelsas/data/services/remote_content_service.dart';
import 'package:betelsas/domain/repositories/favorites_repository.dart';

// Core
final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper());

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

final remoteContentServiceProvider =
    Provider<RemoteContentService>((ref) => RemoteContentService(dio: Dio()));

final contentSyncServiceProvider = Provider<ContentSyncService>((ref) {
  return ContentSyncService(
    remote: ref.watch(remoteContentServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    dbHelper: ref.watch(databaseHelperProvider),
  );
});

// Repositories
final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(dbHelper: ref.watch(databaseHelperProvider));
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return FavoritesRepositoryImpl(dbHelper);
});
