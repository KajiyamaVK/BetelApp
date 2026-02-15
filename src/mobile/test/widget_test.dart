// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betelsas/main.dart';

void main() {
  testWidgets('App starts and displays main scaffold', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: BetelApp()));

    // Verify that our app starts and displays the main scaffold.
    expect(find.byType(MaterialApp), findsOneWidget);
    // You might want to look for specific widgets like BottomNavigationBar if you export it or use keys
    // For now, just ensuring it builds without error is a good start.
    // Let's check for a text that should be on the home screen or navigation
    expect(find.text('Início'), findsOneWidget); 
    expect(find.text('Músicas'), findsOneWidget);
  });
}
