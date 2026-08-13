import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../chat/domain/models/chat_message.dart';

/// One message in a Watch Together chat thread.
///
/// Shares the canonical [ChatMessage] shape and serialization used by the
/// Sanctuary chat; the two chat surfaces differ only in where they persist.
class WatchPartyChatMessage extends ChatMessage {
  WatchPartyChatMessage({
    required super.id,
    required super.sender,
    required super.senderUid,
    required super.text,
    required super.timestamp,
  });

  factory WatchPartyChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return WatchPartyChatMessage(
      id: doc.id,
      sender: (data['sender'] as String?) ?? '',
      senderUid: (data['senderUid'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      timestamp: ChatMessage.parseTimestamp(data['timestamp']),
    );
  }
}
