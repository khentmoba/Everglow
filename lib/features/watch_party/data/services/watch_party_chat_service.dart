import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/watch_party_chat_message.dart';
import '../../../../core/utils/firestore_stream_utils.dart';

class WatchPartyChatService {
  final FirebaseFirestore _db;

  WatchPartyChatService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'watch_party_chats';
  static const String _messagesSubcollection = 'messages';

  Stream<List<WatchPartyChatMessage>> getMessagesStream(String roomId) {
    if (roomId.isEmpty) {
      return Stream<List<WatchPartyChatMessage>>.value(const []);
    }
    return _db
        .collection(_collection)
        .doc(roomId)
        .collection(_messagesSubcollection)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final messages = <WatchPartyChatMessage>[];
          for (final doc in snapshot.docs.reversed) {
            try {
              messages.add(WatchPartyChatMessage.fromFirestore(doc));
            } catch (e) {
              debugPrint(
                'WatchPartyChatService: failed to parse ${doc.id}: $e',
              );
            }
          }
          return messages;
        })
        .handleError((error) {
          debugPrint('WatchPartyChatService stream error: $error');
          if (error.toString().contains('permission-denied')) {
            debugPrint(
              'WatchPartyChatService: check firestore.rules for '
              'watch_party_chats/{roomId}/messages.',
            );
          }
          throw error;
        });
  }

  Future<List<WatchPartyChatMessage>> getMessages(String roomId) async {
    if (roomId.isEmpty) return const [];
    final snap = await withGetTimeout(
      _db
          .collection(_collection)
          .doc(roomId)
          .collection(_messagesSubcollection)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get(),
      label: 'watch party chat history',
    );
    return snap.docs
        .map(WatchPartyChatMessage.fromFirestore)
        .toList()
        .reversed
        .toList(growable: false);
  }

  Future<void> sendMessage({
    required String roomId,
    required String text,
    required String sender,
    required String senderUid,
  }) async {
    if (roomId.isEmpty) {
      throw StateError('WatchPartyChatService.sendMessage: empty roomId');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final message = WatchPartyChatMessage(
      id: '',
      sender: sender,
      senderUid: senderUid,
      text: trimmed,
      timestamp: DateTime.now(),
    );

    try {
      await _db
          .collection(_collection)
          .doc(roomId)
          .collection(_messagesSubcollection)
          .add(message.toMap());
    } catch (e) {
      debugPrint('WatchPartyChatService.sendMessage failed: $e');
      rethrow;
    }
  }

  Future<void> clearMessages(String roomId) async {
    if (roomId.isEmpty) return;
    try {
      final snap = await withGetTimeout(
        _db
            .collection(_collection)
            .doc(roomId)
            .collection(_messagesSubcollection)
            .get(),
        label: 'watch party chat clear scan',
      );
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('WatchPartyChatService.clearMessages failed: $e');
    }
  }
}
