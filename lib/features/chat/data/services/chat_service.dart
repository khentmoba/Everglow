import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../shared/utils/firestore_pagination.dart';
import '../../domain/models/chat_message.dart';
import '../../../../core/utils/logger.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _monthDay(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m-$d';
  }

  static const int messagePageSize = 50;

  Stream<FirestorePage<ChatMessage>> getMessagesStream() {
    return withFirestoreTimeout(
      _db
          .collection('sanctuary_messages')
          .orderBy('timestamp', descending: true)
          .limit(messagePageSize)
          .snapshots()
          .map((snapshot) {
            final messages = <ChatMessage>[];
            for (final doc in snapshot.docs) {
              try {
                messages.add(ChatMessage.fromFirestore(doc));
              } catch (e) {
                Logger.e("Error parsing message document ${doc.id}", error: e);
              }
            }
            return FirestorePage(
              items: messages.reversed.toList(),
              nextCursor: snapshot.docs.length == messagePageSize
                  ? snapshot.docs.last
                  : null,
            );
          }),
      label: 'sanctuary-chat',
      duration: const Duration(seconds: 10),
    );
  }

  Future<FirestorePage<ChatMessage>> getMessagesPage({
    DocumentSnapshot? cursor,
    int limit = messagePageSize,
  }) {
    return fetchFirestorePage<ChatMessage>(
      collection: _db.collection('sanctuary_messages'),
      orderBy: 'timestamp',
      cursor: cursor,
      limit: limit,
      fromDoc: ChatMessage.fromFirestore,
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

      final now = DateTime.now();
      await _db.collection('sanctuary_messages').add({
        ...message.toMap(),
        'monthDay': _monthDay(now),
      });
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
      final monthDay = _monthDay(now);
      var snapshot = await withGetTimeout(
        _db
            .collection('sanctuary_messages')
            .where('monthDay', isEqualTo: monthDay)
            .limit(100)
            .get(),
        label: 'chat on-this-day',
      );

      // Legacy messages predate the monthDay field; bound the fallback.
      if (snapshot.docs.isEmpty) {
        snapshot = await withGetTimeout(
          _db
              .collection('sanctuary_messages')
              .orderBy('timestamp', descending: true)
              .limit(200)
              .get(),
          label: 'chat on-this-day fallback',
        );
      }

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
