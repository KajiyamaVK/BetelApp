import 'package:betelsas/core/connectivity_service.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/core/providers.dart';
import 'package:betelsas/data/services/content_sync_service.dart';
import 'package:betelsas/data/services/remote_content_service.dart';
import 'package:betelsas/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betelsas/main.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _FakeConnectivity extends ConnectivityService {
  @override
  Future<bool> isConnected() async => true;
  @override
  Future<bool> isMobileData() async => false;
}

class _FakeSyncService extends ContentSyncService {
  _FakeSyncService()
      : super(
          remote: RemoteContentService(),
          connectivity: ConnectivityService(),
          dbHelper: DatabaseHelper(),
        );

  @override
  Future<SyncResult> sync({void Function(SyncProgress)? onProgress}) async =>
      SyncResult.upToDate;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('App starts and displays SplashScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
          contentSyncServiceProvider.overrideWithValue(_FakeSyncService()),
        ],
        child: const BetelApp(),
      ),
    );

    // First frame: SplashScreen should be visible
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
