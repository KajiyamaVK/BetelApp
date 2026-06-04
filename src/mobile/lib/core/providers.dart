import 'package:betelapp/core/audio/betel_audio_handler.dart';
import 'package:betelapp/core/network_status_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelapp/core/connectivity_service.dart';
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/data/repositories/content_repository.dart';
import 'package:betelapp/data/repositories/favorites_repository_impl.dart';
import 'package:betelapp/data/repositories/review_repository_impl.dart';
import 'package:betelapp/data/services/content_sync_service.dart';
import 'package:betelapp/data/services/remote_content_service.dart';
import 'package:betelapp/domain/repositories/favorites_repository.dart';
import 'package:betelapp/presentation/screens/reviews/reviews_view_model.dart';

// Core
final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper());

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

final networkStatusProvider =
    StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>((ref) {
  return NetworkStatusNotifier();
});

Dio _buildDioWithInterceptor(Ref ref) {
  final dio = Dio();
  dio.interceptors.add(_NetworkCheckInterceptor(ref));
  return dio;
}

final remoteContentServiceProvider =
    Provider<RemoteContentService>((ref) => RemoteContentService(dio: _buildDioWithInterceptor(ref)));

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

// Review
final reviewRepositoryProvider = Provider<ReviewRepositoryImpl>((ref) {
  return ReviewRepositoryImpl(ref.watch(databaseHelperProvider));
});

final reviewViewModelProvider =
    StateNotifierProvider<ReviewViewModel, AsyncValue<ReviewState>>(
  (ref) => ReviewViewModel(ref.read(reviewRepositoryProvider)),
);

class _NetworkCheckInterceptor extends Interceptor {
  final Ref _ref;
  _NetworkCheckInterceptor(this._ref);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _ref.read(networkStatusProvider.notifier).reportSuccess();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isNetworkError(err)) {
      _ref.read(networkStatusProvider.notifier).check();
    }
    handler.next(err);
  }

  bool _isNetworkError(DioException err) =>
      err.type == DioExceptionType.connectionError ||
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.unknown;
}
