import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/watch_party_chat_message.dart';

/// Persists and streams Watch Together chat messages.
///
/// The chat is scoped to a watch party `roomId` (the deterministic
/// sorted-joined uids; see `WatchPartyRoom.buildRoomId`), so the
/// history is tied to the couple rather than the movie. Switching
/// titles in an ongoing watch party keeps the chat alive.
///
/// Firestore path: `watch_party_chats/{roomId}/messages/{messageId}`.
///
/// The room document at `watch_party_rooms/{roomId}` must already
/// exist (the Watch Together room is created when a party is
/// started). If a chat message is sent before the room doc exists
/// the read/write will be denied by security rules — callers should
/// ensure the room is up first (the start-room flow does this).
class WatchPartyChatService {
  final FirebaseFirestore _db;

  WatchPartyChatService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'watch_party_chats';
  static const String _messagesSubcollection = 'messages';

  /// Live, ordered list of messages in the given room. Newest at
  /// the end. The list will be empty while the room doc is missing
  /// or while the subcollection hasn't been written yet.
  Stream<List<WatchPartyChatMessage>> getMessagesStream(String roomId) {
    if (roomId.isEmpty) {
      return Stream<List<WatchPartyChatMessage>>.value(const []);
    }
    return _db
        .collection(_collection)
        .doc(roomId)
        .collection(_messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      final messages = <WatchPartyChatMessage>[];
      for (final doc in snapshot.docs) {
        try {
          messages.add(WatchPartyChatMessage.fromFirestore(doc));
        } catch (e) {
          debugPrint('WatchPartyChatService: failed to parse ${doc.id}: $e');
        }
      }
      return messages;
    }).handleError((error) {
      debugPrint('WatchPartyChatService stream error: $error');
      if (error.toString().contains('permission-denied')) {
        debugPrint(
          'WatchPartyChatService: check firestore.rules for '
          'watch_party_chats/{roomId}/messages.',
        );
      }
      // Re-throw so the StreamBuilder's hasError branch shows the
      // "Chat is unavailable" message instead of silently showing
      // an empty list.
      throw error;
    });
  }

  /// One-shot fetch used by the drawer to decide between "empty
  /// state" and "loading" on first paint. Not strictly required
  /// since the stream emits the same data, but it's handy for tests
  /// and for analytics.
  Future<List<WatchPartyChatMessage>> getMessages(String roomId) async {
    if (roomId.isEmpty) return const [];
    final snap = await _db
        .collection(_collection)
        .doc(roomId)
        .collection(_messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .get();
    return snap.docs
        .map(WatchPartyChatMessage.fromFirestore)
        .toList(growable: false);
  }

  /// Append a message to the room's chat. The caller is responsible
  /// for trimming the text and for supplying a non-empty payload.
  /// On a permission-denied the future rethrows so the UI can
  /// surface a friendly error instead of silently dropping the
  /// message.
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
}
