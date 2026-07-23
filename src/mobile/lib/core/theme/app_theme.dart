import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFFFFBD00); // Updated Yellow
  static const Color secondaryColor = Colors.white;
  static const Color scaffoldBackgroundColor = Color(0xFFF5F5F5); // Light Grey
  static const Color textColor = Color(0xFF333333); // Dark Grey/Black
  static const Color errorColor = Color(0xFFE57373);
  static const Color updateBannerColor = Color(0xFF2a5298);

  // Text Styles
  static TextStyle get heading1 => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
      );

  static TextStyle get heading2 => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      );

  static TextStyle get bodyText => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textColor,
      );

  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.grey[600],
      );

  // Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: secondaryColor,
        error: errorColor,
      ),
      textTheme: TextTheme(
        displayLarge: heading1,
        displayMedium: heading2,
        bodyLarge: bodyText,
        bodyMedium: bodyText,
        bodySmall: caption,
      ),
      cardTheme: CardThemeData(
        color: secondaryColor,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        titleTextStyle: heading2,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: secondaryColor,
        selectedItemColor: textColor, // Set icon and text color to Black/Dark Grey
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: caption.copyWith(
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationColor: primaryColor,
          decorationThickness: 2.0,
        ),
        unselectedLabelStyle: caption,
      ),
      useMaterial3: true,
    );
  }
}
