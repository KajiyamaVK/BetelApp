import 'package:betelapp/core/network_status_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'network_status_notifier_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
  });

  NetworkStatusNotifier makeNotifier() => NetworkStatusNotifier(dio: mockDio);

  group('initial state', () {
    test('starts as ok', () {
      expect(makeNotifier().state, NetworkStatus.ok);
    });
  });

  group('check() — API HEAD succeeds', () {
    test('status stays ok', () async {
      when(mockDio.head<dynamic>(any)).thenAnswer(
        (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 200),
      );

      final notifier = makeNotifier();
      await notifier.check();

      expect(notifier.state, NetworkStatus.ok);
    });
  });

  group('check() — API HEAD fails, Google HEAD succeeds', () {
    test('status becomes serverDown', () async {
      var callCount = 0;
      when(mockDio.head<dynamic>(any)).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw DioException(requestOptions: RequestOptions(path: ''));
        }
        return Response(requestOptions: RequestOptions(path: ''), statusCode: 200);
      });

      final notifier = makeNotifier();
      await notifier.check();

      expect(notifier.state, NetworkStatus.serverDown);
    });
  });

  group('check() — both API and Google HEAD fail', () {
    test('status becomes noInternet', () async {
      when(mockDio.head<dynamic>(any))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final notifier = makeNotifier();
      await notifier.check();

      expect(notifier.state, NetworkStatus.noInternet);
    });
  });

  group('reportSuccess()', () {
    test('resets status to ok and stops polling after a failed check', () async {
      when(mockDio.head<dynamic>(any))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final notifier = makeNotifier();
      await notifier.check();
      expect(notifier.state, isNot(NetworkStatus.ok));

      notifier.reportSuccess();

      expect(notifier.state, NetworkStatus.ok);
      expect(notifier.isPolling, isFalse);
    });
  });

  group('polling', () {
    test('does not start polling when initial check passes', () async {
      when(mockDio.head<dynamic>(any)).thenAnswer(
        (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 200),
      );

      final notifier = makeNotifier();
      await notifier.check();

      expect(notifier.isPolling, isFalse);
    });

    test('starts polling after serverDown is detected', () async {
      var callCount = 0;
      when(mockDio.head<dynamic>(any)).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw DioException(requestOptions: RequestOptions(path: ''));
        }
        return Response(requestOptions: RequestOptions(path: ''), statusCode: 200);
      });

      final notifier = makeNotifier();
      await notifier.check();

      expect(notifier.state, NetworkStatus.serverDown);
      expect(notifier.isPolling, isTrue);

      notifier.dispose();
    });

    test('starts polling after noInternet is detected', () async {
      when(mockDio.head<dynamic>(any))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final notifier = makeNotifier();
      await notifier.check();

      expect(notifier.isPolling, isTrue);

      notifier.dispose();
    });

    test('stops polling when reportSuccess() is called', () async {
      when(mockDio.head<dynamic>(any))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final notifier = makeNotifier();
      await notifier.check();
      expect(notifier.isPolling, isTrue);

      notifier.reportSuccess();

      expect(notifier.isPolling, isFalse);
    });
  });
}
