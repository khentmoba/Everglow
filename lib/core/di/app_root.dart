import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/watch_party/data/services/voice_chat_bootstrap.dart';
import '../../features/watch_party/presentation/widgets/incoming_watch_party_banner.dart';
import '../../shared/widgets/app_network_image.dart';
import '../system/web_standalone.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Wraps every route (gateway, dashboard, chat, cinema, etc.)
/// so the silent incoming-call banner appears regardless of
/// which screen the user is on. Also keeps the global
/// `VoiceChatService.watchIncoming()` listener in sync with
/// the auth state.
class AppRoot extends StatefulWidget {
  final Widget child;
  const AppRoot({super.key, required this.child});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  AuthService? _authService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthService>();
    if (_authService != auth) {
      _authService?.removeListener(_syncListener);
      _authService = auth;
      auth.addListener(_syncListener);
      _syncListener();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authService?.removeListener(_syncListener);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When waking from sleep or alt-tabbing back, evict stale live
      // image instances so repaints re-decode cleanly rather than holding
      // evicted WebGL textures, and trigger immediate retries for any
      // thumbnails that failed during backgrounding or sleep.
      PaintingBinding.instance.imageCache.clearLiveImages();
      AppNetworkImage.onAppResumed();
    }
  }

  void _syncListener() {
    final auth = _authService;
    if (auth == null || !mounted) return;
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (auth.isCoupleUser && myUid != null && myUid.isNotEmpty) {
      // Voice chunk (flutter_webrtc) loads on demand, in parallel with first
      // paint rather than blocking it. Calls still ring: the watcher starts
      // as soon as the chunk lands, seconds before any call could arrive.
      unawaited(
        VoiceChatBootstrap.watchIncoming(
          myUid: myUid,
          partnerUid: partnerUid,
        ),
      );
      // Expose context to NotificationService for push to navigation.
      NotificationService.setNavContext(context);
    } else {
      VoiceChatBootstrap.clearIncomingWatcher();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AuthService, bool>(
      selector: (_, auth) => auth.isCoupleUser,
      builder: (context, isCoupleUser, child) {
        // Global Home Screen inset: the measured iPhone status-bar overlap
        // is injected into MediaQuery here, so every SafeArea/AppBar below
        // clears it. Kept outside the Stack so banners, dialogs, and every
        // future route inherit it with no per-screen work.
        final app = (!isCoupleUser)
            ? widget.child
            : Stack(
                children: [
                  widget.child,
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: false,
                      // Top-only SafeArea: sits the ringing banner below
                      // the iPhone status bar via the MediaQuery inset
                      // above. No-op everywhere else.
                      child: SafeArea(
                        top: true,
                        bottom: false,
                        left: false,
                        right: false,
                        child: IncomingWatchPartyBanner(),
                      ),
                    ),
                  ),
                ],
              );
        return WebStandaloneInsets(child: app);
      },
    );
  }
}
