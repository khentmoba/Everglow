import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/presence_status.dart';
import '../utils/logger.dart';

class PresenceService {
  PresenceService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _collection = 'presence';
  static const String _sessionsCollection = 'presence_sessions';
  // 180s heartbeat (cost): presence writes are ~15% of the free quota at 60s.
  // Client onlineThreshold (4 min) and server sweep (6 min stale) allow 2 missed beats.
  static const Duration heartbeatInterval = Duration(seconds: 180);
  static const Duration doodleTouchThreshold = Duration(seconds: 15);

  Timer? _heartbeatTimer;
  Timer? _doodleIdleTimer;
  String? _currentUid;
  String? _currentUsername;
  String? _doodlingUid;

  // --- session tracking ---
  String? _activeSessionId;
  DateTime? _sessionStartedAt;

  DocumentReference _doc(String uid) => _db.collection(_collection).doc(uid);
  DocumentReference _sessionDoc(String id) =>
      _db.collection(_sessionsCollection).doc(id);

  /// Streams the presence document for [uid]. Emits a default-empty
  /// [PresenceStatus] when the document does not exist yet.
  Stream<PresenceStatus> watchPresence(String uid) {
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

  /// Starts a periodic heartbeat for [uid] marking them online. Safe to call
  /// repeatedly with the same uid; the previous timer is cancelled.
  void startHeartbeat({required String uid, required String username}) {
    if (uid.isEmpty) return;
    if (_currentUid == uid && _heartbeatTimer != null) return;

    // close previous session if switching user without explicit stopHeartbeat
    if (_currentUid != null && _currentUid != uid && _activeSessionId != null) {
      unawaited(_closeSessionInternal());
    }

    _stopHeartbeat();
    _currentUid = uid;
    _currentUsername = username;

    setOnline(uid: uid, username: username);
    unawaited(_createSession(uid, username));

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

  /// Stops the heartbeat timer and marks the user offline. Call this on
  /// logout, app close, or when leaving the dashboard.
  Future<void> stopHeartbeat() async {
    final uid = _currentUid;
    _stopHeartbeat();
    _currentUid = null;
    _currentUsername = null;
    // close session before marking offline so endedAt ~ lastSeen
    if (uid != null) {
      await _closeSessionInternal();
      await setOffline(uid);
    } else if (_activeSessionId != null) {
      await _closeSessionInternal();
    }
  }

  // ---- session helpers ----

  Future<void> _createSession(String uid, String username) async {
    try {
      final ref = _db.collection(_sessionsCollection).doc();
      _activeSessionId = ref.id;
      _sessionStartedAt = DateTime.now();
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
      _sessionStartedAt = null;
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
    _sessionStartedAt = null;
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

  /// Marks [uid] as online right now. Updates the lastSeen timestamp.
  Future<void> setOnline({
    required String uid,
    required String username,
  }) async {
    if (uid.isEmpty) return;
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

  /// Marks [uid] as offline but keeps the lastSeen timestamp so we can still
  /// compute "active X ago" on the partner's side.
  Future<void> setOffline(String uid) async {
    if (uid.isEmpty) return;
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

  /// Marks [uid] as actively doodling. Throttled internally so calling on
  /// every pan-update is safe. Also starts an idle timer that automatically
  /// clears the doodling flag if no further touches arrive.
  Future<void> markDoodling(String uid) async {
    if (uid.isEmpty) return;
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

  /// Clears the doodling flag for [uid]. Should be called when the user
  /// leaves the canvas screen, or after the idle window expires.
  Future<void> clearDoodling(String uid) async {
    if (uid.isEmpty) return;
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

  /// True if this service currently believes the local user is doodling.
  bool get isDoodling => _doodlingUid != null;

  /// Current active session id, if any (for debugging / testing).
  String? get activeSessionId => _activeSessionId;
}
