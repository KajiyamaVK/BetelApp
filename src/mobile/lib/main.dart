import 'package:betelsas/core/audio/audio_service_initializer.dart';
import 'package:betelsas/core/providers.dart';
import 'package:betelsas/core/theme/app_theme.dart';
import 'package:betelsas/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioHandler = await initAudioService();

  runApp(
    ProviderScope(
      overrides: [
        betelAudioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const BetelApp(),
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
