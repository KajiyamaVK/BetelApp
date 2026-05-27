import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:betelsas/data/services/remote_content_service.dart';
import 'package:betelsas/data/models/manifest.dart';

@GenerateMocks([Dio])
import 'remote_content_service_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late RemoteContentService service;

  setUp(() {
    mockDio = MockDio();
    service = RemoteContentService(dio: mockDio);
  });

  test('fetchManifest returns ContentManifest on success', () async {
    final fakeJson = {
      'version': 1,
      'updated_at': '2026-05-27T12:00:00Z',
      'lessons': [
        {
          'id': 1,
          'title': 'Test',
          'pdf': {'active': 'lessons/1/lesson_v1.pdf', 'checksum': 'abc', 'history': []},
          'audio': null,
        }
      ]
    };

    when(mockDio.get(any)).thenAnswer((_) async => Response(
          data: fakeJson,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    final manifest = await service.fetchManifest();
    expect(manifest.version, 1);
    expect(manifest.lessons.length, 1);
  });

  test('fetchManifest throws RemoteContentException on network error', () async {
    when(mockDio.get(any)).thenThrow(DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.connectionTimeout,
    ));

    expect(() => service.fetchManifest(), throwsA(isA<RemoteContentException>()));
  });

  test('downloadFile completes without exception on success', () async {
    when(mockDio.download(
      any,
      any,
      onReceiveProgress: anyNamed('onReceiveProgress'),
      options: anyNamed('options'),
    )).thenAnswer((_) async => Response(
          data: '',
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    await expectLater(
      service.downloadFile(
          remotePath: 'lessons/1/lesson_v1.pdf', localPath: '/tmp/test.pdf'),
      completes,
    );
  });

  test('downloadFile throws RemoteContentException on network error', () async {
    when(mockDio.download(
      any,
      any,
      onReceiveProgress: anyNamed('onReceiveProgress'),
      options: anyNamed('options'),
    )).thenThrow(DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.connectionTimeout,
    ));

    expect(
      () => service.downloadFile(
          remotePath: 'lessons/1/lesson_v1.pdf', localPath: '/tmp/test.pdf'),
      throwsA(isA<RemoteContentException>()),
    );
  });
}
