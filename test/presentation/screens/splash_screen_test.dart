import 'package:betelsas/presentation/screens/splash_screen.dart';
import 'package:betelsas/presentation/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SplashScreen displays image and navigates to MainScaffold',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    // Verify Image is displayed
    expect(find.byType(Image), findsOneWidget);
    
    // Verify specific image asset is used
    final image = tester.widget<Image>(find.byType(Image));
    final imageProvider = image.image as AssetImage;
    expect(imageProvider.assetName, 'assets/images/splash_screen_image.jpg');

    // Wait for the timer to complete (adjust duration as needed based on implementation)
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify navigation to MainScaffold
    expect(find.byType(MainScaffold), findsOneWidget);
  });
}
