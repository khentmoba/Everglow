import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import '../../../../../core/theme/app_theme.dart';
import '../../../presentation/widgets/web_overlay_button.dart';
import '../../../../../core/theme/app_typography.dart';

class TableTennisGameScreen extends StatefulWidget {
  const TableTennisGameScreen({super.key});

  @override
  State<TableTennisGameScreen> createState() => _TableTennisGameScreenState();
}

class _TableTennisGameScreenState extends State<TableTennisGameScreen> {
  // Local self-contained build of the Famobi Table Tennis World Tour
  // (originally hosted at games.cdn.famobi.com/.../table-tennis-world-tour/,
  // now serving placeholder files). The single-file embed lives at
  // web/table_tennis/index.html and is bundled by `flutter build web`.
  // The `v=1` cache-buster mirrors the hexgl/index.html convention so
  // future updates aren't pinned to a stale iframe HTML by the 1-hour
  // Firebase Hosting CDN cache.
  static const String _gameSrc = 'table_tennis/assets/index.typed.html?v=1';

  late final String _viewType =
      'tabletennis-iframe-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';

  final bool _booted = true;
  bool _isMobile = false;

  @override
  void initState() {
    super.initState();
    _isMobile = _detectMobile();
    if (kIsWeb) {
      _registerIframe();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    try {
      web.document.querySelector('iframe[data-everglow-tt="1"]')?.remove();
    } catch (e) {
      debugPrint(
        '[TableTennisGameScreen] Failed to remove iframe on dispose: $e',
      );
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool _detectMobile() {
    if (kIsWeb) {
      try {
        return web.window.matchMedia('(pointer: coarse)').matches ||
            web.window.matchMedia('(max-width: 900px)').matches;
      } catch (_) {
        return false;
      }
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _registerIframe() {
    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = _gameSrc
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..setAttribute('data-everglow-tt', '1')
      ..allow = 'autoplay *; fullscreen *; pointer-lock *; gamepad *'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('webkitallowfullscreen', 'true')
      ..setAttribute('mozallowfullscreen', 'true')
      ..title = 'Table Tennis World Tour'
      ..tabIndex = 0;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return iframe;
    });
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  void _restart() {
    try {
      final iframe =
          web.document.querySelector('iframe[data-everglow-tt="1"]')
              as web.HTMLIFrameElement?;
      final w = iframe?.contentWindow;
      if (w != null) {
        w.location.reload();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[TableTennisGameScreen] Failed to reload iframe: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isPortrait = mq.size.height > mq.size.width;
    final mobilePortraitBlocked = _isMobile && isPortrait;

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (kIsWeb)
              Positioned.fill(child: HtmlElementView(viewType: _viewType))
            else
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Text(
                    'Table Tennis World Tour is only available in the web build.',
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppTheme.petalWhite,
                    ),
                  ),
                ),
              ),

            if (_booted)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    WebOverlayButton(icon: Icons.close_rounded, onTap: _close),
                    const Spacer(),
                    WebOverlayButton(
                      icon: Icons.replay_rounded,
                      onTap: _restart,
                      tooltip: 'Restart match',
                    ),
                  ],
                ),
              ),

            if (mobilePortraitBlocked)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.screen_rotation_rounded,
                        color: AppTheme.roseQuartz,
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Rotate your device',
                        style: AppTypography.cormorantSemiBoldWhite.copyWith(
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Table Tennis runs in landscape.',
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppTheme.petalWhite.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _close,
                        child: Text(
                          'Back',
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppTheme.petalWhite.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
