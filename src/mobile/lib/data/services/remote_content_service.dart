import 'dart:async';
import 'package:dio/dio.dart';
import 'package:betelapp/data/models/manifest.dart';

const _baseUrl = String.fromEnvironment(
  'CONTENT_BASE_URL',
  defaultValue: 'http://s3.kajiyama.com.br/betelapp-content',
);

class RemoteContentException implements Exception {
  final String message;
  RemoteContentException(this.message);
  @override
  String toString() => 'RemoteContentException: $message';
}

class RemoteContentService {
  final Dio _dio;

  RemoteContentService({Dio? dio}) : _dio = dio ?? Dio();

  Future<ContentManifest> fetchManifest() async {
    try {
      final response = await _dio.get('$_baseUrl/manifest.json');
      return ContentManifest.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw RemoteContentException('Failed to fetch manifest: $e');
    }
  }

  Future<void> downloadFile({
    required String remotePath,
    required String localPath,
    void Function(int received, int total)? onProgress,
    Duration stallTimeout = const Duration(seconds: 3),
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final cancelToken = CancelToken();
      Timer? stallTimer;

      void resetTimer() {
        stallTimer?.cancel();
        stallTimer = Timer(stallTimeout, () => cancelToken.cancel());
      }

      try {
        resetTimer();
        await _dio.download(
          '$_baseUrl/$remotePath',
          localPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            resetTimer();
            onProgress?.call(received, total);
          },
          options: Options(receiveTimeout: const Duration(minutes: 5)),
        );
        stallTimer?.cancel();
        return;
      } on DioException catch (e) {
        stallTimer?.cancel();
        final isRetryable = e.type == DioExceptionType.cancel ||
            e.type == DioExceptionType.unknown;
        if (isRetryable && attempt < maxRetries - 1) {
          continue;
        }
        throw RemoteContentException('Failed to download $remotePath: $e');
      } catch (e) {
        stallTimer?.cancel();
        throw RemoteContentException('Failed to download $remotePath: $e');
      }
    }
  }
}
