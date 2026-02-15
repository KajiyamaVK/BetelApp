import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/presentation/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:betelsas/presentation/screens/splash_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BetelApp(),
    ),
  );
}

class BetelApp extends StatelessWidget {
  const BetelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Betel Catecismo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
