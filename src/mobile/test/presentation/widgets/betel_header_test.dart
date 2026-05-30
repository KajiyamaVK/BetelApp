import 'package:betelsas/presentation/widgets/betel_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BetelHeader displays the app icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BetelHeader(),
        ),
      ),
    );

    expect(find.byType(BetelHeader), findsOneWidget);

    final svgFinder = find.byType(SvgPicture);
    expect(svgFinder, findsOneWidget);

    final containerFinder = find.byType(Container);
    final Container container = tester.widget(containerFinder);
    expect(container.color, Colors.white);

    // Logo is inside a Stack to allow the version badge overlay
    expect(find.byType(Stack), findsWidgets);
  });
}
