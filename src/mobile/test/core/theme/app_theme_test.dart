
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betelsas/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('BottomNavigationBarTheme should have correct selected item styling', () {
      final theme = AppTheme.lightTheme;
      final bottomNavTheme = theme.bottomNavigationBarTheme;

      // Verify selected item color is black (or textColor which is 0xFF333333)
      expect(bottomNavTheme.selectedItemColor, AppTheme.textColor);
      
      // Verify selected label style has underline
      expect(bottomNavTheme.selectedLabelStyle?.decoration, TextDecoration.underline);
      
      // Verify underline color is primary color (Yellow)
      expect(bottomNavTheme.selectedLabelStyle?.decorationColor, AppTheme.primaryColor);

       // Verify underline thickness
      expect(bottomNavTheme.selectedLabelStyle?.decorationThickness, 2.0);
    });
  });
}
