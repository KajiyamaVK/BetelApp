import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class BetelHeader extends StatefulWidget {
  const BetelHeader({super.key});

  @override
  State<BetelHeader> createState() => _BetelHeaderState();
}

class _BetelHeaderState extends State<BetelHeader> {
  bool _updateAvailable = false;
  String _version = '';
  bool _isSideloaded = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _isSideloaded = info.installerStore != 'com.android.vending';
      });
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (mounted &&
          info.updateAvailability == UpdateAvailability.updateAvailable) {
        setState(() => _updateAvailable = true);
      }
    } catch (_) {
      // Silently ignore — update check is non-critical
    }
  }

  Future<void> _startUpdate() async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/betel-topbar-logo.svg',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                  if (_version.isNotEmpty)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSideloaded)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'DEV',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Text(
                            _version,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFFAAAAAA),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_updateAvailable)
              Container(
                width: double.infinity,
                color: const Color(0xFF2a5298),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.system_update,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Nova versão disponível',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    GestureDetector(
                      onTap: _startUpdate,
                      child: const Text(
                        'Atualizar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
