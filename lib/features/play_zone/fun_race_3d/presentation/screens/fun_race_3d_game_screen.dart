import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import '../../../../../core/theme/app_theme.dart';
import '../../../presentation/widgets/web_overlay_button.dart';

class FunRace3DGameScreen extends StatefulWidget {
  const FunRace3DGameScreen({super.key});

  @override
  State<FunRace3DGameScreen> createState() => _FunRace3DGameScreenState();
}

class _FunRace3DGameScreenState extends State<FunRace3DGameScreen> {
  static const String _gameSrc = 'fun_race_3d/index.html?v=1';

  late final String _viewType =
      'funrace3d-iframe-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';

  bool _booted = true;
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
      web.document.querySelector('iframe[data-everglow-fr3d="1"]')?.remove();
    } catch (_) {}
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
      ..setAttribute('data-everglow-fr3d', '1')
      ..allow = 'autoplay; fullscreen; pointer-lock; gamepad'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('webkitallowfullscreen', 'true')
      ..setAttribute('mozallowfullscreen', 'true')
      ..title = 'Fun Race 3D'
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
          web.document.querySelector('iframe[data-everglow-fr3d="1"]')
              as web.HTMLIFrameElement?;
      final w = iframe?.contentWindow;
      if (w != null) {
        w.location.reload();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
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
              Positioned.fill(
                child: HtmlElementView(viewType: _viewType),
              )
            else
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Text(
                    'Fun Race 3D is only available in the web build.',
                    style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                  ),
                ),
              ),

            if (_booted)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    WebOverlayButton(
                      icon: Icons.close_rounded,
                      onTap: _close,
                    ),
                    const Spacer(),
                    WebOverlayButton(
                      icon: Icons.replay_rounded,
                      onTap: _restart,
                      tooltip: 'Restart race',
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
                        style: GoogleFonts.cormorantGaramond(
                          color: AppTheme.petalWhite,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fun Race 3D runs in landscape.',
                        style: GoogleFonts.outfit(
                          color: AppTheme.petalWhite.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _close,
                        child: Text(
                          'Back',
                          style: GoogleFonts.outfit(
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

