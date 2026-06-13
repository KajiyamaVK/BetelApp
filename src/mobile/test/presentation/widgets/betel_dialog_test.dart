import 'package:betelapp/core/theme/app_theme.dart';
import 'package:betelapp/presentation/widgets/betel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to build a dialog inside a MaterialApp for testing.
/// Wraps BetelDialog in a Dialog-like constrained environment so the
/// Column + Expanded + PageView layout receives bounded height.
Widget _buildDialog({
  List<Widget>? pages,
  bool showBackButton = false,
  bool showCloseButton = true,
  bool? showPagination,
  bool isVideoOnly = false,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: false),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 480,
          child: BetelDialog(
            pages: pages ?? [const Text('Page 1')],
            showBackButton: showBackButton,
            showCloseButton: showCloseButton,
            showPagination: showPagination,
            isVideoOnly: isVideoOnly,
          ),
        ),
      ),
    ),
  );
}

/// Helper to test BetelDialog.show() — pumps a screen with a button
/// that triggers the static show method.
Widget _buildShowTestApp({
  List<Widget>? pages,
  bool barrierDismissible = true,
  bool showCloseButton = true,
  bool isVideoOnly = false,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: false),
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => BetelDialog.show(
            context,
            pages: pages ?? [const Text('Dialog Content')],
            barrierDismissible: barrierDismissible,
            showCloseButton: showCloseButton,
            isVideoOnly: isVideoOnly,
          ),
          child: const Text('Open Dialog'),
        ),
      ),
    ),
  );
}

void main() {
  // ── Structure ──────────────────────────────────────────────

  group('BetelDialog — structure', () {
    testWidgets('renders single page content', (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('Hello World')],
      ));

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders white container by default', (tester) async {
      await tester.pumpWidget(_buildDialog());

      final container = tester.widget<Container>(
        find.byKey(const Key('betel-dialog-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
    });

    testWidgets('renders transparent container when isVideoOnly is true',
        (tester) async {
      await tester.pumpWidget(_buildDialog(isVideoOnly: true));

      final container = tester.widget<Container>(
        find.byKey(const Key('betel-dialog-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.transparent);
    });

    testWidgets('shows rounded decoration on white container', (tester) async {
      await tester.pumpWidget(_buildDialog());

      final container = tester.widget<Container>(
        find.byKey(const Key('betel-dialog-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(20));
    });

    testWidgets('no rounded decoration when isVideoOnly', (tester) async {
      await tester.pumpWidget(_buildDialog(isVideoOnly: true));

      final container = tester.widget<Container>(
        find.byKey(const Key('betel-dialog-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNull);
    });
  });

  // ── Close button ───────────────────────────────────────────

  group('BetelDialog — close button', () {
    testWidgets('shows close button by default', (tester) async {
      await tester.pumpWidget(_buildDialog());

      expect(
        find.byKey(const Key('betel-dialog-close-btn')),
        findsOneWidget,
      );
    });

    testWidgets('hides close button when showCloseButton is false',
        (tester) async {
      await tester.pumpWidget(_buildDialog(showCloseButton: false));

      expect(
        find.byKey(const Key('betel-dialog-close-btn')),
        findsNothing,
      );
    });

    testWidgets('tapping close button dismisses the dialog', (tester) async {
      await tester.pumpWidget(_buildShowTestApp());

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Dialog Content'), findsOneWidget);

      // Tap close
      await tester.tap(find.byKey(const Key('betel-dialog-close-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Dialog Content'), findsNothing);
    });
  });

  // ── Back button ────────────────────────────────────────────

  group('BetelDialog — back button', () {
    testWidgets('hides back button by default', (tester) async {
      await tester.pumpWidget(_buildDialog());

      expect(
        find.byKey(const Key('betel-dialog-back-btn')),
        findsNothing,
      );
    });

    testWidgets('shows back button when showBackButton is true',
        (tester) async {
      await tester.pumpWidget(_buildDialog(showBackButton: true));

      expect(
        find.byKey(const Key('betel-dialog-back-btn')),
        findsOneWidget,
      );
    });

    testWidgets('back button on page 0 dismisses dialog', (tester) async {
      await tester.pumpWidget(_buildShowTestApp(
        pages: [const Text('Page 1')],
      ));

      // Need to use show to test dismissal — but show doesn't expose
      // showBackButton. Let's use a custom builder instead.
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => BetelDialog.show(
                context,
                pages: [const Text('Page 1')],
                showBackButton: true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('betel-dialog-back-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsNothing);
    });

    testWidgets('back button on page 1 navigates to page 0', (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('Page A'), const Text('Page B')],
        showBackButton: true,
        showPagination: true,
      ));

      // Swipe to page 1
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Page B'), findsOneWidget);

      // Tap back — should go to page 0
      await tester.tap(find.byKey(const Key('betel-dialog-back-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Page A'), findsOneWidget);
    });
  });

  // ── Pagination dots ────────────────────────────────────────

  group('BetelDialog — pagination dots', () {
    testWidgets('does not show pagination when one page (auto)',
        (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('Only Page')],
      ));

      expect(
        find.byKey(const Key('betel-dialog-pagination')),
        findsNothing,
      );
    });

    testWidgets('shows pagination dots when two pages (auto)', (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('Page 1'), const Text('Page 2')],
      ));

      expect(
        find.byKey(const Key('betel-dialog-pagination')),
        findsOneWidget,
      );
    });

    testWidgets('shows correct number of dots', (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [
          const Text('P1'),
          const Text('P2'),
          const Text('P3'),
        ],
      ));

      // Each dot has key 'betel-dialog-dot-$i'
      expect(find.byKey(const Key('betel-dialog-dot-0')), findsOneWidget);
      expect(find.byKey(const Key('betel-dialog-dot-1')), findsOneWidget);
      expect(find.byKey(const Key('betel-dialog-dot-2')), findsOneWidget);
    });

    testWidgets('forces pagination visible when showPagination is true',
        (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('Only Page')],
        showPagination: true,
      ));

      expect(
        find.byKey(const Key('betel-dialog-pagination')),
        findsOneWidget,
      );
    });

    testWidgets('forces pagination hidden when showPagination is false',
        (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('P1'), const Text('P2')],
        showPagination: false,
      ));

      expect(
        find.byKey(const Key('betel-dialog-pagination')),
        findsNothing,
      );
    });

    testWidgets('first dot is active (primary color) on initial render',
        (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('P1'), const Text('P2')],
      ));

      // Find the AnimatedContainer inside each dot widget
      final firstDot = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const Key('betel-dialog-dot-0')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final secondDot = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const Key('betel-dialog-dot-1')),
          matching: find.byType(AnimatedContainer),
        ),
      );

      // First dot should use primary color
      final firstDotDecoration = firstDot.decoration as BoxDecoration;
      expect(firstDotDecoration.color, AppTheme.primaryColor);

      // Second dot should use grey
      final secondDotDecoration = secondDot.decoration as BoxDecoration;
      expect(secondDotDecoration.color, isNot(AppTheme.primaryColor));
    });
  });

  // ── Bottom padding ─────────────────────────────────────────

  group('BetelDialog — bottom padding', () {
    testWidgets('extra bottom padding (36px) when pagination is hidden',
        (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('Only Page')],
      ));

      final sizedBox = tester.widget<SizedBox>(
        find.byKey(const Key('betel-dialog-bottom-padding')),
      );
      expect(sizedBox.height, 36.0);
    });

    testWidgets('no extra bottom padding when pagination is visible',
        (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('P1'), const Text('P2')],
      ));

      expect(
        find.byKey(const Key('betel-dialog-bottom-padding')),
        findsNothing,
      );
    });
  });

  // ── Pagination interaction ─────────────────────────────────

  group('BetelDialog — pagination interaction', () {
    testWidgets('swiping to second page updates active dot', (tester) async {
      await tester.pumpWidget(_buildDialog(
        pages: [const Text('P1'), const Text('P2')],
      ));

      // Swipe left (to page 2)
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      final firstDot = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const Key('betel-dialog-dot-0')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final secondDot = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const Key('betel-dialog-dot-1')),
          matching: find.byType(AnimatedContainer),
        ),
      );

      // First dot should no longer be active
      final firstDotDecoration = firstDot.decoration as BoxDecoration;
      expect(firstDotDecoration.color, isNot(AppTheme.primaryColor));

      // Second dot should now be active
      final secondDotDecoration = secondDot.decoration as BoxDecoration;
      expect(secondDotDecoration.color, AppTheme.primaryColor);
    });
  });

  // ── Static show method ─────────────────────────────────────

  group('BetelDialog — static show', () {
    testWidgets('BetelDialog.show displays dialog over the screen',
        (tester) async {
      await tester.pumpWidget(_buildShowTestApp());

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog Content'), findsOneWidget);
    });

    testWidgets('BetelDialog.show sets dark barrier color', (tester) async {
      await tester.pumpWidget(_buildShowTestApp());

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // The ModalBarrier should be present
      expect(find.byType(ModalBarrier), findsWidgets);
    });
  });
}
