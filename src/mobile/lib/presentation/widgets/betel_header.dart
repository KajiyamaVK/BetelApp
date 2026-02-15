import 'package:flutter/material.dart';

/// A reusable header widget that displays the app icon at the top of the screen.
/// It should be used at the top of the body of main screens.
class BetelHeader extends StatelessWidget {
  const BetelHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/appIcon.png',
              height: 50,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
