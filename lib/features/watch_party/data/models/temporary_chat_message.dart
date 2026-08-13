import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../chat/domain/models/chat_message.dart';

/// One message in the temporary Watch Together chat.
///
/// Reuses the canonical [ChatMessage] shape; only the Firestore path differs
/// from the persistent party-room chat.
class TemporaryChatMessage extends ChatMessage {
  TemporaryChatMessage({
    required super.id,
    required super.sender,
    required super.senderUid,
    required super.text,
    required super.timestamp,
  });

  factory TemporaryChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return TemporaryChatMessage(
      id: doc.id,
      sender: (data['sender'] as String?) ?? '',
      senderUid: (data['senderUid'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      timestamp: ChatMessage.parseTimestamp(data['timestamp']),
    );
  }
}
