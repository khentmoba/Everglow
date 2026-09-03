import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/watch_party/data/services/voice_chat_bootstrap.dart';
import '../../features/watch_party/presentation/widgets/incoming_watch_party_banner.dart';
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

class _AppRootState extends State<AppRoot> {
  AuthService? _authService;

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
    _authService?.removeListener(_syncListener);
    super.dispose();
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
        if (!isCoupleUser) return widget.child;
        return Stack(
          children: [
            widget.child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: false,
                child: IncomingWatchPartyBanner(),
              ),
            ),
          ],
        );
      },
    );
  }
}
