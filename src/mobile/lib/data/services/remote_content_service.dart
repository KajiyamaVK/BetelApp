import 'package:dio/dio.dart';
import 'package:betelapp/data/models/manifest.dart';

const _baseUrl = 'http://s3.kajiyama.com.br/betelapp-content';

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
  }) async {
    try {
      await _dio.download(
        '$_baseUrl/$remotePath',
        localPath,
        onReceiveProgress: onProgress,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );
    } catch (e) {
      throw RemoteContentException('Failed to download $remotePath: $e');
    }
  }
}
