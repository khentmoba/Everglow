import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/system/desktop_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/logger.dart';

/// Desktop download and update controls on the Dashboard's Desktop App page.
class DesktopAppAction extends StatefulWidget {
  const DesktopAppAction({super.key});

  static final downloadUrl = Uri.parse(
    'https://github.com/khentmoba/Everglow-Desktop/releases/latest/download/Everglow-Desktop-Setup.exe',
  );
  static final releasesUrl = Uri.parse(
    'https://github.com/khentmoba/Everglow-Desktop/releases/latest',
  );

  @override
  State<DesktopAppAction> createState() => _DesktopAppActionState();
}

class _DesktopAppActionState extends State<DesktopAppAction> {
  String? _error;

  Future<void> _activate() async {
    setState(() => _error = null);
    try {
      if (DesktopApp.version != null) {
        DesktopApp.checkForUpdates();
      } else {
        final url = defaultTargetPlatform == TargetPlatform.windows
            ? DesktopAppAction.downloadUrl
            : DesktopAppAction.releasesUrl;
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          throw StateError('Could not open the desktop download');
        }
      }
    } catch (error, stack) {
      Logger.e(
        'Everglow desktop action failed',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() => _error = 'Could not open it. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = DesktopApp.version;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: _activate,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.blushGold,
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(
            version == null ? Icons.download_rounded : Icons.system_update_alt,
            size: 18,
          ),
          label: Text(
            version != null
                ? 'Check for desktop updates'
                : defaultTargetPlatform == TargetPlatform.windows
                ? 'Download for Windows'
                : 'Everglow for Windows',
          ),
        ),
        Text(
          _error ??
              (version == null
                  ? 'Already installed? Use Everglow → Check for Updates.'
                  : 'Everglow Desktop $version'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.petalWhite, fontSize: 12),
        ),
      ],
    );
  }
}
