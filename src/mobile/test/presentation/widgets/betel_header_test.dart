import 'package:betelapp/presentation/widgets/betel_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BetelHeader displays the app icon image', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BetelHeader(),
        ),
      ),
    );

    expect(find.byType(BetelHeader), findsOneWidget);

    // Uses Image widget with appIcon.png, not SvgPicture
    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    // Logo is inside a Stack to allow the version badge overlay
    expect(find.byType(Stack), findsWidgets);
  });

  testWidgets('BetelHeader background matches app icon dark color', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BetelHeader(),
        ),
      ),
    );

    final containerFinder = find.byType(Container).first;
    final Container container = tester.widget(containerFinder);
    expect(container.color, const Color(0xFF25211E));
  });
}
