import 'package:cloud_firestore/cloud_firestore.dart';

/// One message in a Watch Together chat thread. Mirrors the shape of
/// the dashboard's `ChatMessage` (kept as a separate class per the
/// "completely different existence" rule — the two chat surfaces
/// could diverge in the future, and we don't want one to silently
/// drag the other around).
///
/// The chat is persisted in `watch_party_chats/{roomId}/messages/`.
/// The roomId is the deterministic sorted-joined uids (see
/// `WatchPartyRoom.buildRoomId`), so the chat is tied to the couple
/// — not to the movie — and survives media switches.
class WatchPartyChatMessage {
  final String id;
  final String sender;
  final String senderUid;
  final String text;
  final DateTime timestamp;

  const WatchPartyChatMessage({
    required this.id,
    required this.sender,
    required this.senderUid,
    required this.text,
    required this.timestamp,
  });

  factory WatchPartyChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return WatchPartyChatMessage(
      id: doc.id,
      sender: (data['sender'] as String?) ?? '',
      senderUid: (data['senderUid'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'senderUid': senderUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}
