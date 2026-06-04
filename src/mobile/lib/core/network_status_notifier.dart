import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { ok, serverDown, noInternet }

const _apiBaseUrl = String.fromEnvironment(
  'CONTENT_BASE_URL',
  defaultValue: 'http://s3.kajiyama.com.br/betelapp-content',
);
const _googleUrl = 'https://www.google.com';
const _pollInterval = Duration(minutes: 1);

class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  final Dio _dio;
  Timer? _pollTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  NetworkStatusNotifier({
    Dio? dio,
    Stream<List<ConnectivityResult>>? connectivityStream,
  })  : _dio = dio ?? Dio(),
        super(NetworkStatus.ok) {
    final stream = connectivityStream ?? Connectivity().onConnectivityChanged;
    _connectivitySub = stream.listen((results) {
      if (results.every((r) => r == ConnectivityResult.none)) {
        check();
      }
    });
  }

  bool get isPolling => _pollTimer != null;

  Future<void> check() async {
    final newStatus = await _computeStatus();
    state = newStatus;
    if (newStatus != NetworkStatus.ok) {
      _startPolling();
    }
  }

  void reportSuccess() {
    state = NetworkStatus.ok;
    _stopPolling();
  }

  Future<NetworkStatus> _computeStatus() async {
    try {
      await _dio.head<dynamic>(_apiBaseUrl);
      return NetworkStatus.ok;
    } catch (_) {}

    try {
      await _dio.head<dynamic>(_googleUrl);
      return NetworkStatus.serverDown;
    } catch (_) {}

    return NetworkStatus.noInternet;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    final newStatus = await _computeStatus();
    state = newStatus;
    if (newStatus == NetworkStatus.ok) {
      _stopPolling();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _stopPolling();
    super.dispose();
  }
}
