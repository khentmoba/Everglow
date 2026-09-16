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
    return TemporaryChatMessage.fromMap(doc.id, data);
  }

  factory TemporaryChatMessage.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TemporaryChatMessage(
      id: id,
      sender: _toStr(data['sender']),
      senderUid: _toStr(data['senderUid']),
      text: _toStr(data['text']),
      timestamp: ChatMessage.parseTimestamp(data['timestamp']),
    );
  }

  static String _toStr(dynamic value) => value is String ? value : '';
}
