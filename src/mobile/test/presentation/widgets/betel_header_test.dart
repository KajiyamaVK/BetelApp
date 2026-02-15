import 'package:betelsas/presentation/widgets/betel_header.dart';
import 'package:flutter/material.dart';
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

    // Verify that the BetelHeader is present
    expect(find.byType(BetelHeader), findsOneWidget);

    // Verify that an image is displayed
    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    // Verify the image source
    final Image imageWidget = tester.widget(imageFinder);
    final AssetImage imageProvider = imageWidget.image as AssetImage;
    expect(imageProvider.assetName, 'assets/images/appIcon.png');
    expect(imageWidget.height, 50);

    // Verify background color
    final containerFinder = find.byType(Container);
    final Container container = tester.widget(containerFinder);
    expect(container.color, Colors.white);
    expect(container.alignment, Alignment.centerLeft);
  });
}
