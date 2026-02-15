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
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AudioPlayerWidget(),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_next), findsNothing);
  });

  testWidgets('AudioPlayerWidget should show Next button when onNext is provided', (WidgetTester tester) async {
    bool nextCalled = false;
    
    // We need to modify AudioPlayerWidget constructor first to accept onNext, 
    // but TDD says write test first. This test will fail compilation until we update the widget.
    // However, for "Vibe Coding", I can write the test assuming the interface exists, 
    // and then fix the code.
    
    // checks for the button
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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

    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    
    await tester.tap(find.byIcon(Icons.skip_next));
    expect(nextCalled, isTrue);
  });
}
