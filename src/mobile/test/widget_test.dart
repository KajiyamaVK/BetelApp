import 'package:audio_service/audio_service.dart';
import 'package:betelapp/core/audio/betel_audio_handler.dart';
import 'package:betelapp/core/connectivity_service.dart';
import 'package:betelapp/core/database_helper.dart';
import 'package:betelapp/core/providers.dart';
import 'package:betelapp/data/services/content_sync_service.dart';
import 'package:betelapp/domain/repositories/review_repository.dart';
import 'package:betelapp/data/services/remote_content_service.dart';
import 'package:betelapp/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart' show inMemoryDatabasePath;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:betelapp/main.dart';
import 'presentation/providers/audio_provider_test.mocks.dart';

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
  @override
  Future<bool> isConnected() async => true;
  @override
  Future<bool> isMobileData() async => false;
}

class _FakeReviewRepository implements ReviewRepository {
  @override dynamic noSuchMethod(Invocation i) => throw UnimplementedError(i.memberName.toString());
}

class _FakeSyncService extends ContentSyncService {
  _FakeSyncService()
      : super(
          remote: RemoteContentService(),
          connectivity: ConnectivityService(),
          dbHelper: DatabaseHelper(),
          reviewRepo: _FakeReviewRepository(),
        );

  @override
  Future<SyncResult> sync({void Function(SyncProgress)? onProgress, Future<String> Function()? getDocsDir}) async =>
      SyncResult.upToDate;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.resetForTesting(dbPath: inMemoryDatabasePath);
  });

  tearDown(() async {
    DatabaseHelper.resetForTesting();
  });

  testWidgets('App starts and displays SplashScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
          contentSyncServiceProvider.overrideWithValue(_FakeSyncService()),
          betelAudioHandlerProvider.overrideWithValue(_makeStubHandler()),
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
