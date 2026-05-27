import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks if necessary, or just override the provider with a fake/mock notifier
// For simplicity in this widget test, we can override the state directly if possible,
// or mock the AudioNotifier.

class MockAudioNotifier extends AudioNotifier {
  MockAudioNotifier() : super(); // Call super constructor if needed, or mock methods
}

void main() {
  testWidgets('AudioPlayerWidget should NOT show Next button by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: AudioPlayerWidget(),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
  });

  testWidgets('AudioPlayerWidget should show Next button when onNext is provided', (WidgetTester tester) async {
    bool nextCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: AudioPlayerWidget(
              onNext: () {
                nextCalled = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    expect(nextCalled, isTrue);
  });

  testWidgets('AudioPlayerWidget hides restart button when showRestartButton is false',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const Scaffold(
            body: AudioPlayerWidget(showRestartButton: false),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
  });

  testWidgets('AudioPlayerWidget shows restart button by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const Scaffold(
            body: AudioPlayerWidget(),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
  });
}
