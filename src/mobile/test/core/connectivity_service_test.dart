import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betelsas/core/connectivity_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock the connectivity_plus platform channel so it works in VM tests.
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'check') {
        return ['wifi']; // pretend we have wifi
      }
      return null;
    });
  });

  test('ConnectivityService can be instantiated', () {
    expect(() => ConnectivityService(), returnsNormally);
  });

  test('isConnected returns a bool', () async {
    final service = ConnectivityService();
    final result = await service.isConnected();
    expect(result, isA<bool>());
  });

  test('isMobileData returns a bool', () async {
    final service = ConnectivityService();
    final result = await service.isMobileData();
    expect(result, isA<bool>());
  });
}
