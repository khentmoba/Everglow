import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/temporary_chat_message.dart';
import '../../../../core/utils/firestore_stream_utils.dart';

class TemporaryChatService {
  final FirebaseFirestore _db;

  TemporaryChatService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'temporary_chats';
  static const String _messagesSubcollection = 'messages';

  Future<void> ensureRoom({
    required String roomId,
    required String myUid,
    required String partnerUid,
  }) async {
    if (roomId.isEmpty || myUid.isEmpty || partnerUid.isEmpty) return;
    try {
      await _db.collection(_collection).doc(roomId).set({
        'hostUid': myUid,
        'partnerUid': partnerUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('TemporaryChatService.ensureRoom failed: $e');
    }
  }

  Stream<List<TemporaryChatMessage>> getMessagesStream(String roomId) {
    if (roomId.isEmpty) {
      return Stream<List<TemporaryChatMessage>>.value(const []);
    }
    return _db
        .collection(_collection)
        .doc(roomId)
        .collection(_messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .limitToLast(200)
        .snapshots()
        .map((snapshot) {
          final messages = <TemporaryChatMessage>[];
          for (final doc in snapshot.docs) {
            try {
              messages.add(TemporaryChatMessage.fromFirestore(doc));
            } catch (e) {
              debugPrint('TemporaryChatService: failed to parse ${doc.id}: $e');
            }
          }
          return messages;
        })
        .handleError((error) {
          debugPrint('TemporaryChatService stream error: $error');
          throw error;
        });
  }

  Future<void> sendMessage({
    required String roomId,
    required String text,
    required String sender,
    required String senderUid,
  }) async {
    if (roomId.isEmpty) {
      throw StateError('TemporaryChatService.sendMessage: empty roomId');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      await _db
          .collection(_collection)
          .doc(roomId)
          .collection(_messagesSubcollection)
          .add(
            TemporaryChatMessage(
              id: '',
              sender: sender,
              senderUid: senderUid,
              text: trimmed,
              timestamp: DateTime.now(),
            ).toMap(),
          );
    } catch (e) {
      debugPrint('TemporaryChatService.sendMessage failed: $e');
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
        label: 'temporary chat clear scan',
      );
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('TemporaryChatService.clearMessages failed: $e');
      rethrow;
    }
  }
}
