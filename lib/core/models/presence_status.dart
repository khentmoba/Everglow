import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceStatus {
  static const Duration onlineThreshold = Duration(minutes: 4); // > 180s heartbeat + snapshot delay
  static const Duration doodleThreshold = Duration(seconds: 15);

  final String uid;
  final String username;
  final bool isOnlineRaw;
  final DateTime? lastSeen;
  final bool isDoodlingRaw;
  final DateTime? lastDoodleAt;

  const PresenceStatus({
    required this.uid,
    required this.username,
    required this.isOnlineRaw,
    required this.lastSeen,
    required this.isDoodlingRaw,
    required this.lastDoodleAt,
  });

  factory PresenceStatus.empty(String uid) {
    return PresenceStatus(
      uid: uid,
      username: '',
      isOnlineRaw: false,
      lastSeen: null,
      isDoodlingRaw: false,
      lastDoodleAt: null,
    );
  }

  factory PresenceStatus.fromFirestore(String uid, Map<String, dynamic> data) {
    return PresenceStatus(
      uid: uid,
      username: _toStr(data['username']),
      isOnlineRaw: _toBool(data['isOnline']),
      lastSeen: _toDate(data['lastSeen']),
      isDoodlingRaw: _toBool(data['isDoodling']),
      lastDoodleAt: _toDate(data['lastDoodleAt']),
    );
  }

  static String _toStr(dynamic value) => value is String ? value : '';

  static bool _toBool(dynamic value) => value is bool ? value : false;

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool get hasEverBeenSeen => lastSeen != null;

  bool isOnlineAt(DateTime now) {
    if (!isOnlineRaw) return false;
    final seen = lastSeen;
    if (seen == null) return false;
    return now.difference(seen) <= onlineThreshold;
  }

  bool isActivelyDoodlingAt(DateTime now) {
    if (!isDoodlingRaw) return false;
    final last = lastDoodleAt;
    if (last == null) return false;
    return now.difference(last) <= doodleThreshold;
  }

  Duration timeSinceLastSeen(DateTime now) {
    final seen = lastSeen;
    if (seen == null) return Duration.zero;
    final diff = now.difference(seen);
    return diff.isNegative ? Duration.zero : diff;
  }

  Duration timeSinceLastDoodle(DateTime now) {
    final last = lastDoodleAt;
    if (last == null) return Duration.zero;
    final diff = now.difference(last);
    return diff.isNegative ? Duration.zero : diff;
  }
}
