import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/auth_service.dart';
import '../../../presentation/widgets/web_overlay_button.dart';
import '../../services/tt_bridge_service.dart';
import '../../services/tt_multiplayer_service.dart';
import 'package:everglow/core/theme/app_typography.dart';

class TTMultiplayerGameScreen extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const TTMultiplayerGameScreen({
    super.key,
    required this.roomId,
    required this.isHost,
  });

  @override
  State<TTMultiplayerGameScreen> createState() => _TTMultiplayerGameScreenState();
}

class _TTMultiplayerGameScreenState extends State<TTMultiplayerGameScreen> {
  static const String _gameSrc = 'table_tennis/assets/index.html?v=1&mode=mp';

  late final String _viewType =
      'ttmp-iframe-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';

  TTBridgeService? _bridge;
  JSFunction? _messageListener;
  final bool _booted = true;
  bool _isMobile = false;
  final bool _gameEnded = false;
  final int _finalScore = 0;

  @override
  void initState() {
    super.initState();
    _isMobile = _detectMobile();
    if (kIsWeb) {
      _registerIframe();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initBridge();
      });
      _messageListener = _onMessage.toJS;
      web.window.addEventListener('message', _messageListener);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    if (_messageListener != null) {
      web.window.removeEventListener('message', _messageListener);
    }
    _bridge?.dispose();
    try {
      web.document.querySelector('iframe[data-everglow-tt="1"]')?.remove();
    } catch (e) {
      debugPrint('[TTMultiplayerGameScreen] Failed to remove iframe on dispose: $e');
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onMessage(web.Event event) {
    TTMultiplayerState.handleMessage(event as web.MessageEvent);
  }

  void _initBridge() {
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null) return;

    _bridge = TTBridgeService(mpService: TTMultiplayerService());
    _bridge!.connect(
      roomId: widget.roomId,
      isHost: widget.isHost,
    );
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
    _bridge?.disconnect();
    Navigator.of(context).maybePop();
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
                    'Table Tennis is only available in the web build.',
                    style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite),
                  ),
                ),
              ),

            if (_booted)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 12,
                child: WebOverlayButton(
                  icon: Icons.close_rounded,
                  onTap: _close,
                ),
              ),

            if (_gameEnded)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _finalScore > 0
                              ? Icons.emoji_events_rounded
                              : Icons.sentiment_dissatisfied_rounded,
                          size: 64,
                          color: _finalScore > 0
                              ? AppTheme.warmAmber
                              : AppTheme.softLavender,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _finalScore > 0 ? 'You Win!' : 'Game Over',
                          style: AppTypography.cormorantBold.copyWith(fontSize: 36),
                        ),
                        const SizedBox(height: 32),
                        TextButton(
                          onPressed: _close,
                          child: Text(
                            'Back to Hub',
                            style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        style: AppTypography.cormorantSemiBoldWhite.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Table Tennis runs in landscape.',
                        style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.75)),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _close,
                        child: Text(
                          'Back',
                          style: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.7)),
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
