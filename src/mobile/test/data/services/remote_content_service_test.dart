import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:betelapp/data/services/remote_content_service.dart';
import 'package:betelapp/data/models/manifest.dart';

@GenerateMocks([Dio])
import 'remote_content_service_test.mocks.dart';

void main() {
  late MockDio mockDio;
  late RemoteContentService service;

  setUp(() {
    mockDio = MockDio();
    service = RemoteContentService(dio: mockDio);
  });

  Response<dynamic> _okResponse() => Response(
        data: '',
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

  DioException _cancelException() => DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.cancel,
      );

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
      cancelToken: anyNamed('cancelToken'),
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
      cancelToken: anyNamed('cancelToken'),
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

  group('stall timeout / retry', () {
    const stallTimeout = Duration(milliseconds: 50);

    test('completes without retry when download progresses steadily', () async {
      var callCount = 0;
      when(mockDio.download(
        any,
        any,
        onReceiveProgress: anyNamed('onReceiveProgress'),
        cancelToken: anyNamed('cancelToken'),
        options: anyNamed('options'),
      )).thenAnswer((inv) async {
        callCount++;
        final cb = inv.namedArguments[#onReceiveProgress] as ProgressCallback?;
        // Deliver progress every 20ms — well within the 50ms stall window
        for (var i = 1; i <= 3; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          cb?.call(i * 100, 300);
        }
        return _okResponse();
      });

      await service.downloadFile(
        remotePath: 'lessons/1/lesson.pdf',
        localPath: '/tmp/test.pdf',
        stallTimeout: stallTimeout,
      );

      expect(callCount, 1);
    });

    test('retries once when download stalls then succeeds on second attempt',
        () async {
      var callCount = 0;
      when(mockDio.download(
        any,
        any,
        onReceiveProgress: anyNamed('onReceiveProgress'),
        cancelToken: anyNamed('cancelToken'),
        options: anyNamed('options'),
      )).thenAnswer((inv) async {
        callCount++;
        final token = inv.namedArguments[#cancelToken] as CancelToken?;
        if (callCount == 1) {
          // First attempt: stall — wait for cancellation
          await token!.whenCancel;
          throw _cancelException();
        }
        return _okResponse();
      });

      await service.downloadFile(
        remotePath: 'lessons/1/lesson.pdf',
        localPath: '/tmp/test.pdf',
        stallTimeout: stallTimeout,
      );

      expect(callCount, 2);
    });

    test('throws RemoteContentException after 3 consecutive stalled attempts',
        () async {
      var callCount = 0;
      when(mockDio.download(
        any,
        any,
        onReceiveProgress: anyNamed('onReceiveProgress'),
        cancelToken: anyNamed('cancelToken'),
        options: anyNamed('options'),
      )).thenAnswer((inv) async {
        callCount++;
        final token = inv.namedArguments[#cancelToken] as CancelToken?;
        await token!.whenCancel;
        throw _cancelException();
      });

      await expectLater(
        service.downloadFile(
          remotePath: 'lessons/1/lesson.pdf',
          localPath: '/tmp/test.pdf',
          stallTimeout: stallTimeout,
        ),
        throwsA(isA<RemoteContentException>()),
      );

      expect(callCount, 3);
    });

    test('resets stall timer when new bytes arrive mid-download', () async {
      var callCount = 0;
      when(mockDio.download(
        any,
        any,
        onReceiveProgress: anyNamed('onReceiveProgress'),
        cancelToken: anyNamed('cancelToken'),
        options: anyNamed('options'),
      )).thenAnswer((inv) async {
        callCount++;
        final cb = inv.namedArguments[#onReceiveProgress] as ProgressCallback?;
        final token = inv.namedArguments[#cancelToken] as CancelToken?;
        // Deliver one chunk at 40ms (just under the 50ms window), then one more at 80ms
        await Future.delayed(const Duration(milliseconds: 40));
        cb?.call(100, 300);
        await Future.delayed(const Duration(milliseconds: 40));
        cb?.call(200, 300);
        await Future.delayed(const Duration(milliseconds: 40));
        cb?.call(300, 300);
        if (token?.isCancelled == true) throw _cancelException();
        return _okResponse();
      });

      await service.downloadFile(
        remotePath: 'lessons/1/lesson.pdf',
        localPath: '/tmp/test.pdf',
        stallTimeout: stallTimeout,
      );

      expect(callCount, 1);
    });
  });
}
