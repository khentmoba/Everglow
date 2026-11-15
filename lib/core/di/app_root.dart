import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/watch_party/data/services/voice_chat_bootstrap.dart';
import '../../features/watch_party/presentation/widgets/incoming_watch_party_banner.dart';
import '../../features/entry/data/welcome_gift_service.dart';
import '../../features/entry/presentation/widgets/welcome_gift_gate.dart';
import '../../shared/widgets/app_network_image.dart';
import '../system/web_standalone.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AppRoot extends StatefulWidget {
  final Widget child;
  const AppRoot({super.key, required this.child});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  AuthService? _authService;
  String? _lastPushSessionKey;

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
      PaintingBinding.instance.imageCache.clearLiveImages();
      AppNetworkImage.onAppResumed();
    }
  }

  void _syncListener() {
    final auth = _authService;
    if (auth == null || !mounted) return;
    final pushSessionKey =
        '${auth.uid ?? 'none'}:${auth.isReady}:${auth.isCoupleUser}:${auth.isAgentSession}';
    if (_lastPushSessionKey != pushSessionKey) {
      _lastPushSessionKey = pushSessionKey;
      unawaited(
        NotificationService.instance.syncAuthSession(
          enabled: auth.isReady && auth.isCoupleUser && !auth.isAgentSession,
        ),
      );
    }
    final myUid = auth.uid;
    final partnerUid = auth.partnerUid;
    if (!auth.isAgentSession &&
        auth.isCoupleUser &&
        myUid != null &&
        myUid.isNotEmpty) {
      unawaited(
        VoiceChatBootstrap.watchIncoming(myUid: myUid, partnerUid: partnerUid),
      );
      NotificationService.setNavContext(context);
    } else {
      VoiceChatBootstrap.clearIncomingWatcher();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AuthService, (bool, String?)>(
      selector: (_, auth) => (
        auth.isCoupleUser && !auth.isAgentSession,
        WelcomeGiftService.recipientUid(
          username: auth.currentUser,
          uid: auth.uid,
          authenticated: auth.isAuthenticated && auth.isSessionLoaded,
          agentSession: auth.isAgentSession,
        ),
      ),
      builder: (context, session, child) {
        final (isCoupleUser, giftRecipientUid) = session;
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
        return WebStandaloneInsets(
          child: WelcomeGiftGate(recipientUid: giftRecipientUid, child: app),
        );
      },
    );
  }
}
