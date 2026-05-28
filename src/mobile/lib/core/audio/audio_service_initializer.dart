import 'package:audio_service/audio_service.dart';
import 'package:betelsas/core/audio/betel_audio_handler.dart';

Future<BetelAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => BetelAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.betelsas.audio',
      androidNotificationChannelName: 'Betel Música',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
    ),
  );
}
