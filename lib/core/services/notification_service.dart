import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/env_config.dart';
import '../../core/theme/app_theme.dart';

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
    case 'milestone':
    case 'special_day':
    case 'special_day_upcoming':
      return '/dashboard';
    case 'mood_checkin':
      return '/dashboard';
    default:
      return null;
  }
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<RemoteMessage>? _foregroundSub;
  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();

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
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized) return;
    } catch (e) {
      debugPrint("Warning: FCM requestPermission failed: $e");
      return;
    }

    try {
      final vapidKey = EnvConfig.fcmVapidKey;
      final token = kIsWeb && vapidKey.isNotEmpty
          ? await _messaging.getToken(vapidKey: vapidKey)
          : await _messaging.getToken();
      if (token != null) await _saveToken(token);

      _messaging.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint("Warning: FCM getToken failed: $e");
    }

    try {
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        _messageController.add(message);
        _showForegroundNotification(message);
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _messageController.add(message);
        _navigateFromNotification(message);
      });
    } catch (e) {
      debugPrint("Warning: FCM listener setup failed: $e");
    }
  }

  /// Shows a themed in-app SnackBar when a push arrives while the app is open.
  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final messenger = _scaffoldMessengerKey?.currentState;
    if (messenger == null) return;

    // Remove any existing snackbar before showing a new one
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
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.blushGold,
                ),
              ),
            if (body.isNotEmpty)
              Text(
                body,
                style: GoogleFonts.outfit(
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
          side: BorderSide(
            color: AppTheme.blushGold.withValues(alpha: 0.25),
          ),
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
    final route = routeFromNotification(message.data);
    if (route == null || _navContext == null) return;
    try {
      GoRouter.of(_navContext!).go(route);
    } catch (e) {
      debugPrint("Warning: Navigation from notification failed: $e");
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('fcm_tokens').doc(uid).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': defaultTargetPlatform.toString(),
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _messageController.close();
  }
}
