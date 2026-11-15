import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../agent/agent_mode.dart';
import '../models/presence_status.dart';
import '../utils/logger.dart';

class PresenceService {
  PresenceService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _collection = 'presence';
  static const String _sessionsCollection = 'presence_sessions';
  static const Duration heartbeatInterval = Duration(seconds: 180);
  static const Duration doodleTouchThreshold = Duration(seconds: 15);

  Timer? _heartbeatTimer;
  Timer? _doodleIdleTimer;
  String? _currentUid;
  String? _currentUsername;
  String? _doodlingUid;

  String? _activeSessionId;

  bool get _demo => AgentMode.isActive.value && AgentMode.useDemoData.value;

  DocumentReference _doc(String uid) => _db.collection(_collection).doc(uid);
  DocumentReference _sessionDoc(String id) =>
      _db.collection(_sessionsCollection).doc(id);

  Stream<PresenceStatus> watchPresence(String uid) {
    if (_demo) return Stream.value(PresenceStatus.empty(uid));
    return _doc(uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data == null) return PresenceStatus.empty(uid);
          return PresenceStatus.fromFirestore(uid, data);
        })
        .handleError((error) {
          Logger.e('PresenceService watchPresence error', error: error);
          return PresenceStatus.empty(uid);
        });
  }

  void startHeartbeat({required String uid, required String username}) {
    if (uid.isEmpty || _demo) return;
    if (_currentUid == uid && _heartbeatTimer != null) return;

    if (_currentUid != null && _currentUid != uid && _activeSessionId != null) {
      unawaited(_closeSessionInternal());
    }

    _stopHeartbeat();
    _currentUid = uid;
    _currentUsername = username;

    setOnline(uid: uid, username: username);
    if (_activeSessionId == null) {
      unawaited(_createSession(uid, username));
    } else {
      unawaited(_touchSession());
    }

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      final id = _currentUid;
      if (id == null) return;
      setOnline(uid: id, username: _currentUsername ?? '');
      unawaited(_touchSession());
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _doodleIdleTimer?.cancel();
    _doodleIdleTimer = null;
    _doodlingUid = null;
  }

  Future<void> stopHeartbeat() async {
    final uid = _currentUid;
    _stopHeartbeat();
    _currentUid = null;
    _currentUsername = null;
    if (uid != null) {
      await _closeSessionInternal();
      await setOffline(uid);
    } else if (_activeSessionId != null) {
      await _closeSessionInternal();
    }
  }

  Future<void> _createSession(String uid, String username) async {
    try {
      final ref = _db.collection(_sessionsCollection).doc();
      _activeSessionId = ref.id;
      await ref.set({
        'uid': uid,
        'username': username,
        'startedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Logger.i('PresenceService session started ${ref.id} for $username');
    } catch (e) {
      Logger.e('PresenceService _createSession failed', error: e);
      _activeSessionId = null;
    }
  }

  Future<void> _touchSession() async {
    final sid = _activeSessionId;
    if (sid == null) return;
    try {
      await _sessionDoc(sid).set({
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.e('PresenceService _touchSession failed', error: e);
    }
  }

  Future<void> _closeSessionInternal() async {
    final sid = _activeSessionId;
    _activeSessionId = null;
    if (sid == null) return;
    try {
      await _sessionDoc(sid).set({
        'endedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Logger.i('PresenceService session closed $sid');
    } catch (e) {
      Logger.e('PresenceService _closeSession failed', error: e);
    }
  }

  Future<void> setOnline({
    required String uid,
    required String username,
  }) async {
    if (uid.isEmpty || _demo) return;
    try {
      await _doc(uid).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'username': username,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.e(
        'PresenceService.setOnline FAILED for $uid ($username)',
        error: e,
      );
    }
  }

  Future<void> setOffline(String uid) async {
    if (uid.isEmpty || _demo) return;
    if (_currentUid == uid) _stopHeartbeat();
    try {
      await _doc(uid).set({
        'isOnline': false,
        'isDoodling': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.e('PresenceService.setOffline FAILED for $uid', error: e);
    }
  }

  Future<void> markDoodling(String uid) async {
    if (uid.isEmpty || _demo) return;
    _doodlingUid = uid;
    try {
      await _doc(uid).set({
        'isOnline': true,
        'isDoodling': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastDoodleAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.e('PresenceService markDoodling error', error: e);
    }

    _doodleIdleTimer?.cancel();
    _doodleIdleTimer = Timer(doodleTouchThreshold, () {
      clearDoodling(uid);
    });
  }

  Future<void> clearDoodling(String uid) async {
    if (uid.isEmpty || _demo) return;
    if (_doodlingUid != uid) {
      _doodleIdleTimer?.cancel();
      _doodleIdleTimer = null;
      return;
    }
    _doodlingUid = null;
    _doodleIdleTimer?.cancel();
    _doodleIdleTimer = null;
    try {
      await _doc(uid).set({
        'isDoodling': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.e('PresenceService clearDoodling error', error: e);
    }
  }

  bool get isDoodling => _doodlingUid != null;

  String? get activeSessionId => _activeSessionId;
}
