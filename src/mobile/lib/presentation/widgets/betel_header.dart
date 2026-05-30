import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A reusable header widget that displays the app icon at the top of the screen.
/// It should be used at the top of the body of main screens.
class BetelHeader extends StatelessWidget {
  const BetelHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1e1e1e),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Center(
            child: SvgPicture.asset(
              'assets/images/betel-navbar-logo.svg',
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
