import 'package:betelapp/core/providers.dart';
import 'package:betelapp/data/services/content_sync_service.dart';
import 'package:betelapp/presentation/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _runSync();
  }

  Future<void> _runSync() async {
    final connectivity = ref.read(connectivityServiceProvider);
    final syncService = ref.read(contentSyncServiceProvider);

    final isMobile = await connectivity.isMobileData();
    if (isMobile && mounted) {
      final shouldProceed = await _showMobileDataDialog();
      if (!shouldProceed) {
        if (mounted) _navigate(SyncResult.offlineWithData);
        return;
      }
    }

    final result = await syncService.sync(
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _statusMessage =
                'Baixando lição ${progress.current} de ${progress.total}…';
          });
        }
      },
    );

    if (mounted) _navigate(result);
  }

  Future<bool> _showMobileDataDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Dados Móveis'),
            content: const Text(
                'Você está em dados móveis. Deseja baixar o conteúdo agora?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Agora não'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Baixar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _navigate(SyncResult result) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainScaffold(syncResult: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/images/splash_screen_image.jpg',
              fit: BoxFit.contain,
            ),
          ),
          if (_statusMessage.isNotEmpty)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
