import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/core/utils/firestore_stream_utils.dart';
import '../../domain/models/chat_message.dart';
import '../../../../core/utils/logger.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ChatMessage>> getMessagesStream() {
    return withFirestoreTimeout(
      _db
          .collection('sanctuary_messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) {
        final messages = <ChatMessage>[];
        for (var doc in snapshot.docs) {
          try {
            messages.add(ChatMessage.fromFirestore(doc));
          } catch (e) {
            Logger.e("Error parsing message document ${doc.id}", error: e);
          }
        }
        return messages;
      }),
      label: 'sanctuary-chat',
      duration: const Duration(seconds: 10),
    );
  }

  Future<void> sendMessage(String text, String sender, String senderUid) async {
    if (text.trim().isEmpty) return;
    
    try {
      final message = ChatMessage(
        id: '',
        sender: sender,
        senderUid: senderUid,
        text: text.trim(),
        timestamp: DateTime.now(),
      );

      await _db.collection('sanctuary_messages').add(message.toMap());
    } catch (e) {
      if (e.toString().contains("permission-denied")) {
        // Surface as a user-visible error in the chat screen instead of print.
        rethrow;
      }
      rethrow;
    }
  }

  /// "On This Day" — chat messages from the same month+day in previous years.
  Future<List<ChatMessage>> getMessagesFromThisDay() async {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    try {
      final snapshot = await _db
          .collection('sanctuary_messages')
          .orderBy('timestamp', descending: true)
          .get();

      final results = <ChatMessage>[];
      for (final doc in snapshot.docs) {
        final msg = ChatMessage.fromFirestore(doc);
        if (msg.timestamp.month == month &&
            msg.timestamp.day == day &&
            msg.timestamp.year != now.year) {
          results.add(msg);
        }
      }
      return results;
    } catch (e) {
      Logger.e("Error getting on-this-day messages", error: e);
      return [];
    }
  }
}
