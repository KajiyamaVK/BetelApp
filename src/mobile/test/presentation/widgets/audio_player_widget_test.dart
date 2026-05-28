import 'package:betelsas/presentation/providers/audio_provider.dart';
import 'package:betelsas/presentation/widgets/audio_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Wraps AudioPlayerWidget in a parent that can be forced to rebuild,
// simulating what happens in MusicScreen (ConsumerWidget) when the
// audioProvider emits position ticks during a drag.
class _RebuildableParent extends StatefulWidget {
  const _RebuildableParent({super.key, required this.child});
  final Widget child;

  @override
  State<_RebuildableParent> createState() => _RebuildableParentState();
}

class _RebuildableParentState extends State<_RebuildableParent> {
  void forceRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.child;
}

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

  // Regression: slider position must not reset to zero when the provider
  // emits a position update while the user is dragging. Without a stable Key
  // on AudioPlayerWidget, a parent rebuild discards _isDragging state and the
  // slider snaps back.
  testWidgets(
      'slider position is preserved during drag even when parent rebuilds',
      (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        audioProvider.overrideWith(
          (ref) => AudioNotifier()
            ..state = const AudioState(
              currentUrl: 'test.mp3',
              currentTitle: 'Test',
              currentArtist: 'Betel',
              duration: Duration(seconds: 100),
              position: Duration(seconds: 10),
              isPlaying: true,
            ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final parentKey = GlobalKey<_RebuildableParentState>();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: _RebuildableParent(
              key: parentKey,
              child: const AudioPlayerWidget(
                key: ValueKey('music-screen-player'),
              ),
            ),
          ),
        ),
      ),
    );

    // Start a drag on the slider
    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    final sliderRect = tester.getRect(slider);
    // Gesture down at ~50% of the slider width (position 50)
    final gesture = await tester.startGesture(
      Offset(sliderRect.left + sliderRect.width * 0.5, sliderRect.center.dy),
    );
    await tester.pump();

    // Simulate provider emitting a position tick (as onPositionChanged would)
    container.read(audioProvider.notifier).state =
        container.read(audioProvider).copyWith(position: const Duration(seconds: 11));
    await tester.pump();

    // Force the parent to rebuild, as a ConsumerWidget would on each position tick
    parentKey.currentState!.forceRebuild();
    await tester.pump();

    // The slider value must still reflect the drag position (~50), not reset to
    // the provider's position (11) or zero.
    final sliderWidget = tester.widget<Slider>(slider);
    expect(
      sliderWidget.value,
      greaterThan(30.0),
      reason: 'Slider must not snap to provider position while dragging',
    );

    await gesture.up();
    await tester.pump();
  });

  // Regression: without a stable Key, _isDragging is reset when the parent
  // rebuilds and the slider jumps to zero on touch. Verify that onChangeEnd
  // (seek) is actually called when drag completes.
  testWidgets('seek is called when drag ends', (WidgetTester tester) async {
    bool seekCalled = false;
    final container = ProviderContainer(
      overrides: [
        audioProvider.overrideWith((ref) {
          final notifier = AudioNotifier();
          notifier.state = const AudioState(
            currentUrl: 'test.mp3',
            currentTitle: 'Test',
            currentArtist: 'Betel',
            duration: Duration(seconds: 100),
            position: Duration(seconds: 10),
            isPlaying: true,
          );
          // Intercept seek via state observation — we can't mock AudioNotifier
          // directly, so we verify state changes to position after drag end.
          return notifier;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const Scaffold(
            body: AudioPlayerWidget(key: ValueKey('music-screen-player')),
          ),
        ),
      ),
    );

    final slider = find.byType(Slider);
    final sliderRect = tester.getRect(slider);

    // Drag from the left edge all the way to 80% — this guarantees the slider
    // lands at ~80s (out of 100s) regardless of starting position.
    final startX = sliderRect.left + sliderRect.width * 0.1;
    final endX = sliderRect.left + sliderRect.width * 0.8;
    final gesture = await tester.startGesture(
      Offset(startX, sliderRect.center.dy),
    );
    await tester.pump();
    await gesture.moveTo(Offset(endX, sliderRect.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // After drag, the provider position should have been updated via seek()
    // (the optimistic update in seek() sets state.position)
    final finalPosition = container.read(audioProvider).position;
    expect(
      finalPosition.inSeconds,
      greaterThan(10),
      reason: 'seek() should have advanced the position after drag',
    );
  });
}
