import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> isMobileData() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.wifi);
  }
}
