import 'package:audio_service/audio_service.dart';
import 'package:betelsas/core/audio/betel_audio_handler.dart';

// Retries AudioService.init() with exponential backoff. This is necessary
// because on fresh install / reinstall, Android's MediaBrowserService binding
// can hang indefinitely if the previous app process is still being torn down.
// Retrying gives the OS time to finish cleanup before we bind again.
Future<BetelAudioHandler> initAudioService({int maxAttempts = 5}) async {
  const config = AudioServiceConfig(
    androidNotificationChannelId: 'com.betelsas.audio',
    androidNotificationChannelName: 'Betel Música',
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: true,
  );

  Duration delay = const Duration(milliseconds: 500);
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await AudioService.init(
        builder: () => BetelAudioHandler(),
        config: config,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      if (attempt == maxAttempts) rethrow;
      await Future.delayed(delay);
      delay *= 2;
    }
  }
  throw StateError('AudioService.init failed after $maxAttempts attempts');
}
