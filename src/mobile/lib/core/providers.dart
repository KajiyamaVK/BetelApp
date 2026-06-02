import 'package:betelapp/core/audio/betel_audio_handler.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelapp/core/connectivity_service.dart';
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/repositories/content_repository.dart';
import 'package:betelapp/data/repositories/favorites_repository_impl.dart';
import 'package:betelapp/data/services/content_sync_service.dart';
import 'package:betelapp/data/services/remote_content_service.dart';
import 'package:betelapp/domain/repositories/favorites_repository.dart';

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

// Overridden in main() after AudioService.init()
final betelAudioHandlerProvider = Provider<BetelAudioHandler>(
  (ref) => throw UnimplementedError('betelAudioHandlerProvider must be overridden in main()'),
);
