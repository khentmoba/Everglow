import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/temporary_chat_message.dart';

/// Realtime temporary chat between the couple, independent of whether
/// a watch party room is currently active.
///
/// Firestore path: `temporary_chats/{roomId}/messages/{messageId}`.
/// The parent document stores `hostUid` and `partnerUid` so security
/// rules can restrict access to exactly those two users. Messages are
/// ephemeral by design: the UI offers a clear action and nothing else
/// in the app treats this thread as permanent history.
class TemporaryChatService {
  final FirebaseFirestore _db;

  TemporaryChatService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'temporary_chats';
  static const String _messagesSubcollection = 'messages';

  /// Ensures the couple's parent document exists. Both clients call
  /// this before streaming so the messages subcollection is readable
  /// immediately.
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

  /// Live, oldest-first list of messages for the couple's temporary chat.
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

  /// Appends a message. Re-throws so the UI can show a friendly error.
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

  /// Deletes every message in the temporary chat.
  Future<void> clearMessages(String roomId) async {
    if (roomId.isEmpty) return;
    try {
      final snap = await _db
          .collection(_collection)
          .doc(roomId)
          .collection(_messagesSubcollection)
          .get();
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
