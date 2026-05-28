import 'package:audio_service/audio_service.dart';
import 'package:betelsas/core/audio/betel_audio_handler.dart';
import 'package:betelsas/core/connectivity_service.dart';
import 'package:betelsas/core/database_helper.dart';
import 'package:betelsas/core/providers.dart';
import 'package:betelsas/data/services/content_sync_service.dart';
import 'package:betelsas/data/services/remote_content_service.dart';
import 'package:betelsas/presentation/screens/splash_screen.dart';
import 'package:betelsas/presentation/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';

import '../providers/audio_provider_test.mocks.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

BetelAudioHandler _makeStubHandler() {
  final handler = MockBetelAudioHandler();
  when(handler.playbackState).thenAnswer((_) => BehaviorSubject.seeded(PlaybackState()));
  when(handler.mediaItem).thenAnswer((_) => BehaviorSubject.seeded(null));
  when(handler.play()).thenAnswer((_) async {});
  when(handler.pause()).thenAnswer((_) async {});
  when(handler.stop()).thenAnswer((_) async {});
  when(handler.seek(any)).thenAnswer((_) async {});
  when(handler.skipToNext()).thenAnswer((_) async {});
  when(handler.skipToPrevious()).thenAnswer((_) async {});
  when(handler.setQueue(any, startIndex: anyNamed('startIndex'))).thenAnswer((_) async {});
  when(handler.songList).thenReturn([]);
  when(handler.currentIndex).thenReturn(0);
  return handler;
}

class _FakeConnectivity extends ConnectivityService {
  final bool mobile;
  _FakeConnectivity({this.mobile = false});

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<bool> isMobileData() async => mobile;
}

class _FakeSyncService extends ContentSyncService {
  final SyncResult _result;

  _FakeSyncService(this._result)
      : super(
          remote: RemoteContentService(),
          connectivity: ConnectivityService(),
          dbHelper: DatabaseHelper(),
        );

  @override
  Future<SyncResult> sync({void Function(SyncProgress)? onProgress}) async =>
      _result;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  SyncResult syncResult = SyncResult.upToDate,
  bool onMobile = false,
}) {
  return ProviderScope(
    overrides: [
      connectivityServiceProvider
          .overrideWithValue(_FakeConnectivity(mobile: onMobile)),
      contentSyncServiceProvider
          .overrideWithValue(_FakeSyncService(syncResult)),
      betelAudioHandlerProvider.overrideWithValue(_makeStubHandler()),
    ],
    child: const MaterialApp(home: SplashScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('SplashScreen displays splash image', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, 'assets/images/splash_screen_image.jpg');
  });

  testWidgets('SplashScreen navigates to MainScaffold after sync',
      (tester) async {
    await tester.pumpWidget(_buildApp(syncResult: SyncResult.upToDate));
    // Allow the async sync future to complete and navigation to run.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MainScaffold), findsOneWidget);
  });

  testWidgets(
      'SplashScreen shows mobile-data dialog when on mobile',
      (tester) async {
    await tester.pumpWidget(
        _buildApp(syncResult: SyncResult.updated, onMobile: true));
    await tester.pump(); // initState fires _runSync, isMobileData awaited
    await tester.pump(const Duration(milliseconds: 50));

    // Dialog should appear
    expect(find.text('Dados Móveis'), findsOneWidget);
    expect(find.text('Agora não'), findsOneWidget);
    expect(find.text('Baixar'), findsOneWidget);
  });

  testWidgets(
      'SplashScreen navigates to MainScaffold after confirming mobile-data dialog',
      (tester) async {
    await tester.pumpWidget(
        _buildApp(syncResult: SyncResult.updated, onMobile: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Baixar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MainScaffold), findsOneWidget);
  });

  testWidgets(
      'SplashScreen navigates to MainScaffold after dismissing mobile-data dialog',
      (tester) async {
    await tester.pumpWidget(
        _buildApp(syncResult: SyncResult.updated, onMobile: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Agora não'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MainScaffold), findsOneWidget);
  });
}
