import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AudioPlayerWidget does NOT show Previous button by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const Scaffold(body: AudioPlayerWidget()),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
  });

  testWidgets('AudioPlayerWidget shows Previous button when onPrevious is provided',
      (WidgetTester tester) async {
    bool previousCalled = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: AudioPlayerWidget(
              onPrevious: () {
                previousCalled = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    expect(previousCalled, isTrue);
  });

  testWidgets('AudioPlayerWidget does NOT show Next button by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const Scaffold(body: AudioPlayerWidget()),
        ),
      ),
    );

    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
  });

  testWidgets('AudioPlayerWidget shows Next button when onNext is provided',
      (WidgetTester tester) async {
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
}
