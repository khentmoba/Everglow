import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/env_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}

/// Parses an FCM data payload and returns the target route for navigation.
String? routeFromNotification(Map<String, dynamic> data) {
  switch (data['type']) {
    case 'chat_message':
      return '/sanctuary';
    case 'mood_update':
      return '/dashboard';
    case 'starlight_drop':
      return '/starlight';
    case 'watchlist_update':
      return '/cinema';
    case 'milestone':
    case 'special_day':
    case 'special_day_upcoming':
      return '/dashboard';
    case 'mood_checkin':
      return '/dashboard';
    case 'motchi_note':
      return '/motchi';
    case 'daily_digest':
    case 'night_recap':
      return '/motchi-today';
    case 'gallery_photo':
      return '/gallery';
    case 'watch_party_invite':
      return '/dashboard';
    default:
      return null;
  }
}

typedef PushIdentity = ({String username, String uid});

class NotificationService {
  NotificationService({
    @visibleForTesting Future<PushIdentity?> Function()? identityProvider,
    @visibleForTesting Future<String?> Function()? tokenProvider,
    @visibleForTesting
    Future<void> Function(String username, String uid, String token)?
    tokenWriter,
    @visibleForTesting
    Future<void> Function(String username, String token)? tokenRemover,
    @visibleForTesting Future<void> Function()? tokenRevoker,
    @visibleForTesting Future<String?> Function()? storedTokenProvider,
    @visibleForTesting Future<void> Function(String? token)? tokenStorage,
    @visibleForTesting bool permissionGranted = false,
  }) : _identityProvider = identityProvider,
       _tokenProvider = tokenProvider,
       _tokenWriter = tokenWriter,
       _tokenRemover = tokenRemover,
       _tokenRevoker = tokenRevoker,
       _storedTokenProvider = storedTokenProvider,
       _tokenStorage = tokenStorage,
       _permissionGranted = permissionGranted;

  static final NotificationService instance = NotificationService._();
  NotificationService._()
    : _identityProvider = null,
      _tokenProvider = null,
      _tokenWriter = null,
      _tokenRemover = null,
      _tokenRevoker = null,
      _storedTokenProvider = null,
      _tokenStorage = null;

  final Future<PushIdentity?> Function()? _identityProvider;
  final Future<String?> Function()? _tokenProvider;
  final Future<void> Function(String username, String uid, String token)?
  _tokenWriter;
  final Future<void> Function(String username, String token)? _tokenRemover;
  final Future<void> Function()? _tokenRevoker;
  final Future<String?> Function()? _storedTokenProvider;
  final Future<void> Function(String? token)? _tokenStorage;
  late final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;
  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();
  Future<void> _operations = Future.value();
  PushIdentity? _activeIdentity;
  PushIdentity? _registeredIdentity;
  String? _registeredToken;
  int _sessionGeneration = 0;
  bool _permissionGranted = false;
  bool _listenersStarted = false;

  Stream<RemoteMessage> get onMessage => _messageController.stream;

  /// Global navigator context — set from the widget tree after mount.
  static BuildContext? _navContext;
  static void setNavContext(BuildContext context) {
    _navContext = context;
  }

  /// Global ScaffoldMessenger key for showing SnackBars from anywhere.
  static GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;
  static void setScaffoldMessengerKey(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldMessengerKey = key;
  }

  Future<void> initialize() async {
    _startListeners();
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      Logger.e('FCM requestPermission failed', error: e);
      return;
    }
    if (_permissionGranted && _activeIdentity != null) {
      await syncAuthSession(enabled: true);
    }
  }

  void _startListeners() {
    if (_listenersStarted) return;
    _listenersStarted = true;
    try {
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        if (!_hasActiveCoupleSession) return;
        _messageController.add(message);
        _showForegroundNotification(message);
      });
      _tokenRefreshSub = _messaging.onTokenRefresh.listen(_onTokenRefresh);
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (!_hasActiveCoupleSession) return;
        _messageController.add(message);
        _navigateFromNotification(message);
      });
    } catch (e) {
      Logger.e('FCM listener setup failed', error: e);
    }
  }

  bool get _hasActiveCoupleSession {
    final identity = _activeIdentity;
    return identity != null && _auth.currentUser?.uid == identity.uid;
  }

  /// Refreshes push registration only from the signed-in Firebase token's
  /// custom couple identity. SharedPreferences profile names are never trusted.
  Future<void> syncAuthSession({required bool enabled}) async {
    final generation = ++_sessionGeneration;
    PushIdentity? identity;
    try {
      if (enabled) identity = await _verifiedIdentity();
    } catch (e) {
      Logger.e('FCM auth identity check failed', error: e);
    }
    if (generation != _sessionGeneration) return;

    final previous = _activeIdentity;
    _activeIdentity = identity;
    try {
      await _enqueue(() async {
        if (identity == null) {
          await _removeRegisteredDevice(previous);
          return;
        }
        final registered = _registeredIdentity;
        if (registered != null && registered.username != identity.username) {
          await _removeRegisteredDevice(registered);
        }
        if (!_isCurrent(generation, identity) || !_permissionGranted) return;
        final token = await _getToken();
        if (token == null || !_isCurrent(generation, identity)) return;
        await _registerToken(identity, token, generation);
      });
    } catch (e) {
      Logger.e('FCM device registration failed', error: e);
    }
  }

  /// Removes this installation's registration and revokes its FCM token.
  /// AuthService awaits this before signing out so no legacy token is left live.
  Future<void> unregisterForLogout() async {
    ++_sessionGeneration;
    final previous = _activeIdentity;
    _activeIdentity = null;
    await _enqueue(() async {
      final identity =
          _registeredIdentity ?? previous ?? await _verifiedIdentity();
      final token = identity == null
          ? null
          : _registeredToken ?? await _getStoredToken();
      if (identity != null && token != null) {
        await _removeToken(identity.username, token);
        await _revokeToken();
        try {
          await _storeToken(null);
        } catch (e) {
          Logger.e('FCM local token cleanup failed', error: e);
        }
      }
      _registeredIdentity = null;
      _registeredToken = null;
    });
  }

  Future<PushIdentity?> _verifiedIdentity() async {
    if (_identityProvider != null) return _identityProvider();
    final user = _auth.currentUser;
    if (user == null) return null;
    final claims = (await user.getIdTokenResult()).claims ?? const {};
    final firebase = claims['firebase'];
    final username = claims['username'];
    if (firebase is! Map ||
        firebase['sign_in_provider'] != 'custom' ||
        username is! String ||
        !{'khentsgdz', 'clairjassen'}.contains(username) ||
        _auth.currentUser?.uid != user.uid) {
      return null;
    }
    return (username: username, uid: user.uid);
  }

  bool _isCurrent(int generation, PushIdentity identity) =>
      generation == _sessionGeneration &&
      _activeIdentity?.uid == identity.uid &&
      _activeIdentity?.username == identity.username &&
      (_identityProvider != null || _auth.currentUser?.uid == identity.uid);

  Future<String?> _getToken() async {
    if (_tokenProvider != null) return _tokenProvider();
    final vapidKey = EnvConfig.fcmVapidKey;
    return kIsWeb && vapidKey.isNotEmpty
        ? _messaging.getToken(vapidKey: vapidKey)
        : _messaging.getToken();
  }

  Future<void> _registerToken(
    PushIdentity identity,
    String token,
    int generation,
  ) async {
    final oldIdentity = _registeredIdentity;
    final oldToken = _registeredToken;
    if (oldIdentity != null &&
        oldToken != null &&
        (oldIdentity.username != identity.username || oldToken != token)) {
      await _removeToken(oldIdentity.username, oldToken);
      _registeredIdentity = null;
      _registeredToken = null;
    }
    if (!_isCurrent(generation, identity)) return;
    await _storeToken(token);
    if (!_isCurrent(generation, identity)) return;
    await _writeToken(identity, token);
    _registeredIdentity = identity;
    _registeredToken = token;
  }

  Future<void> _removeRegisteredDevice(PushIdentity? fallback) async {
    final identity = _registeredIdentity ?? fallback;
    if (identity == null) return;
    final token = _registeredToken ?? await _getStoredToken();
    if (token == null) return;
    await _removeToken(identity.username, token);
    if (_registeredIdentity?.username == identity.username &&
        _registeredToken == token) {
      _registeredIdentity = null;
      _registeredToken = null;
    }
  }

  Future<void> _writeToken(PushIdentity identity, String token) async {
    if (_tokenWriter != null) {
      await _tokenWriter(identity.username, identity.uid, token);
      return;
    }
    await _deviceRef(identity.username, token).set({
      'token': token,
      'uid': identity.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': defaultTargetPlatform.toString(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeToken(String username, String token) async {
    if (_tokenRemover != null) {
      await _tokenRemover(username, token);
      return;
    }
    await _deviceRef(username, token).delete();
  }

  DocumentReference<Map<String, dynamic>> _deviceRef(
    String username,
    String token,
  ) => _firestore
      .collection('fcm_tokens')
      .doc(username)
      .collection('devices')
      .doc(sha256.convert(utf8.encode(token)).toString());

  Future<String?> _getStoredToken() async {
    if (_storedTokenProvider != null) return _storedTokenProvider();
    return (await SharedPreferences.getInstance()).getString(
      'fcm_device_token',
    );
  }

  Future<void> _storeToken(String? token) async {
    if (_tokenStorage != null) {
      await _tokenStorage(token);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('fcm_device_token');
    } else {
      await prefs.setString('fcm_device_token', token);
    }
  }

  Future<void> _revokeToken() async {
    if (_tokenRevoker != null) {
      await _tokenRevoker();
    } else {
      await _messaging.deleteToken();
    }
  }

  void _onTokenRefresh(String token) {
    final identity = _activeIdentity;
    final generation = _sessionGeneration;
    if (identity == null || !_permissionGranted) return;
    unawaited(
      _enqueue(() async {
        if (!_isCurrent(generation, identity)) return;
        await _registerToken(identity, token, generation);
      }),
    );
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        Logger.e(
          'FCM token operation failed',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    return result;
  }

  /// Shows a themed in-app SnackBar when a push arrives while the app is open.
  void _showForegroundNotification(RemoteMessage message) {
    if (!_hasActiveCoupleSession) return;
    final notification = message.notification;
    if (notification == null) return;

    final messenger = _scaffoldMessengerKey?.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();

    final title = notification.title ?? '';
    final body = notification.body ?? '';
    final data = message.data;
    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: AppTypography.outfitHeading.copyWith(
                  fontSize: 13,
                  color: AppTheme.blushGold,
                ),
              ),
            if (body.isNotEmpty)
              Text(
                body,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 12,
                  color: AppTheme.petalWhite.withValues(alpha: 0.85),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: AppTheme.velvet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.blushGold.withValues(alpha: 0.25)),
        ),
        duration: const Duration(seconds: 4),
        action: routeFromNotification(data) != null
            ? SnackBarAction(
                label: 'View',
                textColor: AppTheme.blushGold,
                onPressed: () => _navigateFromNotification(message),
              )
            : null,
      ),
    );
  }

  /// Navigates to the relevant screen based on notification type.
  void _navigateFromNotification(RemoteMessage message) {
    if (!_hasActiveCoupleSession) return;
    final route = routeFromNotification(message.data);
    if (route == null || _navContext == null) return;
    try {
      GoRouter.of(_navContext!).go(route);
    } catch (e) {
      Logger.e('Navigation from notification failed', error: e);
    }
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _messageController.close();
  }
}
