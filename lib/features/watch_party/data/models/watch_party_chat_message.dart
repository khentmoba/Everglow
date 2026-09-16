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
    return WatchPartyChatMessage.fromMap(doc.id, data);
  }

  factory WatchPartyChatMessage.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return WatchPartyChatMessage(
      id: id,
      sender: _toStr(data['sender']),
      senderUid: _toStr(data['senderUid']),
      text: _toStr(data['text']),
      timestamp: ChatMessage.parseTimestamp(data['timestamp']),
    );
  }

  static String _toStr(dynamic value) => value is String ? value : '';
}
