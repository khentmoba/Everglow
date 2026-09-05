import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/firestore_stream_utils.dart';

import '../models/watch_party_room.dart';

/// Manages the lifecycle of a real-time "Watch Together" room between
/// Khent and Clair. The room is a single Firestore document at
/// `watch_party_rooms/{roomId}`. Every state transition (play, pause,
/// seek, end) is written here, and both clients subscribe via
/// [getRoomStream] so the partner's player reacts in real time.
///
/// Concurrency model:
///   * The host writes `state` + `currentTime` whenever they change
///     something, and additionally ticks a heartbeat every 5s with
///     the latest known playback position so the partner's local
///     estimate stays fresh.
///   * The partner writes nothing except on user actions (resync,
///     end) — they read the snapshot and reload their iframe with
///     a new `?start=` hint when the host changes things.
class WatchPartyService {
  static const String _collection = 'watch_party_rooms';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Build the deterministic room id from the two partners' uids. Both
  /// clients call this, sort the uids the same way, and land on the
  /// same document — no manual "share a code" step.
  String roomIdFor(String uidA, String uidB) =>
      WatchPartyRoom.buildRoomId(uidA, uidB);

  /// Create a new room or revive an existing one. If a room already
  /// exists for this couple-pair and it's still active, we update
  /// it in place (the host re-opens the screen → re-broadcasts the
  /// new media selection) instead of leaving a stale doc around.
  Future<WatchPartyRoom> startRoom({
    required String hostUid,
    required String hostName,
    required String partnerUid,
    required String partnerName,
    required String mediaType,
    required int tmdbId,
    int? malId,
    bool isAnime = false,
    int? season,
    int? episode,
    required String title,
    required String posterPath,
  }) async {
    final id = roomIdFor(hostUid, partnerUid);
    final now = DateTime.now();
    final room = WatchPartyRoom(
      id: id,
      hostUid: hostUid,
      hostName: hostName,
      partnerUid: partnerUid,
      partnerName: partnerName,
      mediaType: mediaType,
      tmdbId: tmdbId,
      malId: malId,
      isAnime: isAnime,
      season: season,
      episode: episode,
      title: title,
      posterPath: posterPath,
      state: 'paused',
      currentTime: 0.0,
      updatedAt: now,
      updatedBy: hostUid,
      createdAt: now,
      active: true,
    );

    try {
      await _db
          .collection(_collection)
          .doc(id)
          .set(room.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('WatchPartyService.startRoom failed: $e\n$st');
      rethrow;
    }
    return room;
  }

  /// Live snapshot of a room. Emits `null` when the doc doesn't exist
  /// (e.g. the partner hasn't opened the sheet yet), otherwise the
  /// parsed [WatchPartyRoom].
  Stream<WatchPartyRoom?> getRoomStream(String roomId) {
    return withFirestoreTimeout(
      _db.collection(_collection).doc(roomId).snapshots().map((snap) {
        if (!snap.exists) return null;
        try {
          return WatchPartyRoom.fromFirestore(snap);
        } catch (e) {
          debugPrint('WatchPartyService.getRoomStream parse error: $e');
          return null;
        }
      }),
      label: 'watch-party-room',
    );
  }

  /// One-shot fetch — used to decide whether the dashboard "Watch
  /// Together" card should show "Resume Party" vs "Start a Party".
  Future<WatchPartyRoom?> getRoom(String roomId) async {
    final snap = await _db.collection(_collection).doc(roomId).get();
    if (!snap.exists) return null;
    return WatchPartyRoom.fromFirestore(snap);
  }

  /// Push a new playback state. The host calls this when the user
  /// hits Play/Pause/Seek; the partner calls it on Resync. We only
  /// patch the fields that change so we don't overwrite the host's
  /// metadata if there's a race.
  Future<void> updatePlayback({
    required String roomId,
    required String state, // 'playing' | 'paused' | 'buffering'
    required double currentTime,
    required String updatedBy,
  }) async {
    try {
      await _db.collection(_collection).doc(roomId).update({
        'state': state,
        'currentTime': currentTime,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'updatedBy': updatedBy,
        'active': true,
      });
    } catch (e) {
      debugPrint('WatchPartyService.updatePlayback failed: $e');
      // Don't rethrow — a dropped heartbeat shouldn't crash the
      // player. The next tick (5s later) will succeed.
    }
  }

  /// Cheap, throttled "I'm still here" tick. The host writes
  /// currentTime every [_tickInterval] seconds while playing so the
  /// partner's local clock stays roughly in sync even without an
  /// explicit play/pause action.
  Future<void> heartbeat({
    required String roomId,
    required String state,
    required double currentTime,
    required String updatedBy,
  }) async {
    try {
      await _db.collection(_collection).doc(roomId).update({
        'state': state,
        'currentTime': currentTime,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'updatedBy': updatedBy,
      });
    } catch (_) {
      // Best effort.
    }
  }

  /// Switch the room to a different movie/episode without ending the
  /// party. Resets playback to 0 so both clients start the new title
  /// at the same time.
  Future<void> updateMedia({
    required String roomId,
    required String mediaType,
    required int tmdbId,
    int? malId,
    bool isAnime = false,
    int? season,
    int? episode,
    required String title,
    required String posterPath,
    required String updatedBy,
  }) async {
    try {
      await _db.collection(_collection).doc(roomId).update({
        'mediaType': mediaType,
        'tmdbId': tmdbId,
        // ignore: use_null_aware_elements
        if (malId != null) 'malId': malId,
        // ignore: use_null_aware_elements
        if (season != null) 'season': season,
        // ignore: use_null_aware_elements
        if (episode != null) 'episode': episode,
        'isAnime': isAnime,
        'title': title,
        'posterPath': posterPath,
        'state': 'paused',
        'currentTime': 0.0,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'updatedBy': updatedBy,
      });
    } catch (e) {
      debugPrint('WatchPartyService.updateMedia failed: $e');
    }
  }

  /// Switch the room to a different playback server without ending the
  /// party. Resets playback so both clients start the new stream at the
  /// same position. Mirror of the AniChan player's server switcher:
  /// the active server travels on the room document.
  Future<void> updateServer({
    required String roomId,
    String? serverType,
    String? serverName,
    String? serverHost,
    String? streamUrl,
    String? subtitleUrl,
    bool proxyEnabled = false,
    required String updatedBy,
  }) async {
    try {
      await _db.collection(_collection).doc(roomId).update({
        // ignore: use_null_aware_elements
        if (serverType != null) 'serverType': serverType,
        // ignore: use_null_aware_elements
        if (serverName != null) 'serverName': serverName,
        // ignore: use_null_aware_elements
        if (serverHost != null) 'serverHost': serverHost,
        // ignore: use_null_aware_elements
        if (streamUrl != null) 'streamUrl': streamUrl,
        // ignore: use_null_aware_elements
        if (subtitleUrl != null) 'subtitleUrl': subtitleUrl,
        'proxyEnabled': proxyEnabled,
        'state': 'paused',
        'currentTime': 0.0,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'updatedBy': updatedBy,
      });
    } catch (e) {
      debugPrint('WatchPartyService.updateServer failed: $e');
    }
  }

  /// Return the room to the default embed-provider list by deleting the
  /// server fields from the room document.
  Future<void> clearServer({
    required String roomId,
    required String updatedBy,
  }) async {
    try {
      await _db.collection(_collection).doc(roomId).update({
        'serverType': FieldValue.delete(),
        'serverName': FieldValue.delete(),
        'serverHost': FieldValue.delete(),
        'streamUrl': FieldValue.delete(),
        'subtitleUrl': FieldValue.delete(),
        'proxyEnabled': false,
        'state': 'paused',
        'currentTime': 0.0,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'updatedBy': updatedBy,
      });
    } catch (e) {
      debugPrint('WatchPartyService.clearServer failed: $e');
    }
  }

  /// End the party. Sets `active=false` and leaves the document in
  /// place (so the dashboard can show "Party ended 5m ago" for a
  /// brief grace period) but flips it so the partner's listener
  /// closes their player screen.
  Future<void> endRoom(String roomId) async {
    try {
      await _db.collection(_collection).doc(roomId).update({
        'active': false,
        'state': 'paused',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('WatchPartyService.endRoom failed: $e');
    }
  }

  /// Hard-delete a room doc. Used for cleanup if both users have
  /// bounced and we want to start fresh.
  Future<void> deleteRoom(String roomId) async {
    try {
      await _db.collection(_collection).doc(roomId).delete();
    } catch (e) {
      debugPrint('WatchPartyService.deleteRoom failed: $e');
    }
  }

  /// Stream of all rooms where `hostUid == uid` OR
  /// `partnerUid == uid`, restricted to active ones. The dashboard
  /// uses this to surface an "Active watch party" banner with a
  /// Resume button.
  Stream<WatchPartyRoom?> watchActiveRoomFor(String uid) {
    return _db
        .collection(_collection)
        .where('active', isEqualTo: true)
        .limit(20)
        .snapshots()
        .map((snap) {
          for (final doc in snap.docs) {
            final data = doc.data();
            if (data['hostUid'] == uid || data['partnerUid'] == uid) {
              return WatchPartyRoom.fromFirestore(doc);
            }
          }
          return null;
        });
  }
}
