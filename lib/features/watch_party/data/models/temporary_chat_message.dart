import 'package:cloud_firestore/cloud_firestore.dart';

/// One message in the temporary Watch Together chat.
///
/// Unlike the persisted party-room chat, this thread is explicitly
/// temporary: it lives in `temporary_chats/{roomId}/messages`, is
/// cleared with the "Clear chat" action, and is scoped to the couple
/// that owns the deterministic room id.
class TemporaryChatMessage {
  final String id;
  final String sender;
  final String senderUid;
  final String text;
  final DateTime timestamp;

  const TemporaryChatMessage({
    required this.id,
    required this.sender,
    required this.senderUid,
    required this.text,
    required this.timestamp,
  });

  factory TemporaryChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return TemporaryChatMessage(
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
