import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/env_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<RemoteMessage>? _foregroundSub;
  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onMessage => _messageController.stream;

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
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _messageController.add(message);
      });
    } catch (e) {
      debugPrint("Warning: FCM listener setup failed: $e");
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
