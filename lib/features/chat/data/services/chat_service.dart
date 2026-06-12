import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ChatMessage>> getMessagesStream() {
    print("Listening to chat messages stream...");
    return _db
        .collection('sanctuary_messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      print("Received ${snapshot.docs.length} documents from sanctuary_messages");
      final messages = <ChatMessage>[];
      for (var doc in snapshot.docs) {
        try {
          messages.add(ChatMessage.fromFirestore(doc));
        } catch (e) {
          print("Error parsing message document ${doc.id}: $e");
        }
      }
      return messages;
    }).handleError((error) {
      print("CRITICAL: Chat stream error: $error");
      if (error.toString().contains("permission-denied")) {
        print("FIX: Check Firestore Security Rules for 'sanctuary_messages' collection.");
      }
      return <ChatMessage>[];
    });

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
}
