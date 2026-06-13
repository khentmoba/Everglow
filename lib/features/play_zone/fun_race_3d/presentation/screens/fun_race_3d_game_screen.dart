import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import '../../../../../core/theme/app_theme.dart';

class FunRace3DGameScreen extends StatefulWidget {
  const FunRace3DGameScreen({super.key});

  @override
  State<FunRace3DGameScreen> createState() => _FunRace3DGameScreenState();
}

class _FunRace3DGameScreenState extends State<FunRace3DGameScreen> {
  static const String _gameSrc = 'fun_race_3d/index.html?v=1';

  late final String _viewType =
      'funrace3d-iframe-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';

  bool _booted = false;
  String _statusText = 'Loading Fun Race 3D...';
  bool _isMobile = false;

  @override
  void initState() {
    super.initState();
    _isMobile = _detectMobile();
    if (kIsWeb) {
      _registerIframe();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _statusText = '');
      });
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
        setState(() {
          _booted = false;
        });
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

            if (!_booted)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (!mounted) return;
                    setState(() {
                      _booted = true;
                      _statusText = '';
                    });
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.85),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'FUN RACE',
                          style: GoogleFonts.cormorantGaramond(
                            color: AppTheme.roseQuartz,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '3D',
                          style: GoogleFonts.cormorantGaramond(
                            color: AppTheme.blushGold,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_statusText.isEmpty) ...[
                          Text(
                            'Tap anywhere to start',
                            style: GoogleFonts.outfit(
                              color: AppTheme.blushGold,
                              fontSize: 18,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Swipe or use arrow keys to dodge obstacles',
                            style: GoogleFonts.outfit(
                              color: AppTheme.petalWhite.withValues(alpha: 0.55),
                              fontSize: 13,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: AppTheme.roseQuartz,
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusText,
                            style: GoogleFonts.outfit(
                              color: AppTheme.petalWhite.withValues(alpha: 0.65),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
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
                    _hudButton(
                      icon: Icons.close_rounded,
                      onTap: _close,
                    ),
                    const Spacer(),
                    _hudButton(
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

  Widget _hudButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.petalWhite.withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          child: Icon(icon, color: AppTheme.petalWhite, size: 22),
        ),
      ),
    );
  }
}
