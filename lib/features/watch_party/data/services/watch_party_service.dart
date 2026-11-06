import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';

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

  WatchPartyService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// In-memory rooms for Agent Mode. Couple data is private, so the demo
  /// path never touches Firestore; it behaves like a tiny local store so
  /// every watch-party screen stays testable without a login.
  static final Map<String, WatchPartyRoom> _demoRooms = {};
  // ignore: close_sinks — process-wide demo stream, lives for the session.
  static final StreamController<List<WatchPartyRoom>> _demoRoomChanges =
      StreamController<List<WatchPartyRoom>>.broadcast();

  static bool get _isDemo => AgentMode.isActive.value;

  static List<WatchPartyRoom> _demoList() {
    final rooms = _demoRooms.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rooms;
  }

  static void _seedDemo(String myUid, String partnerUid) {
    if (_demoRooms.isNotEmpty) return;
    for (final room in AgentFixtures.demoWatchPartyRooms(
      myUid: myUid,
      partnerUid: partnerUid,
    )) {
      _demoRooms[room.id] = room;
    }
    _demoRoomChanges.add(_demoList());
  }

  static void _putDemo(WatchPartyRoom room) {
    _demoRooms[room.id] = room;
    _demoRoomChanges.add(_demoList());
  }

  /// Create a named room. No code, no password: both couple profiles can
  /// see every room and walk in. The room starts empty so whoever opens
  /// it can pick the first title.
  Future<WatchPartyRoom> createRoom({
    required String hostUid,
    required String hostName,
    required String partnerUid,
    required String partnerName,
    required String name,
    String mediaType = 'movie',
    int tmdbId = 0,
    int? malId,
    bool isAnime = false,
    int? season,
    int? episode,
    int? episodeCount,
    String title = '',
    String posterPath = '',
  }) async {
    final now = DateTime.now();
    final ref = _isDemo
        ? null
        : _db.collection(_collection).doc();
    final room = WatchPartyRoom(
      id: ref?.id ?? 'demo_${now.microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Our room' : name.trim(),
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
      episodeCount: episodeCount,
      title: title,
      posterPath: posterPath,
      serverType: 'everglow',
      serverName: 'Everglow',
      serverHost: 'everglow',
      state: 'paused',
      currentTime: 0.0,
      positionAt: now,
      updatedAt: now,
      updatedBy: hostUid,
      createdAt: now,
      active: true,
    );

    if (_isDemo) {
      _putDemo(room);
      return room;
    }
    try {
      final data = room.toFirestore();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['positionAt'] = FieldValue.serverTimestamp();
      await ref!.set(data);
    } catch (e, st) {
      Logger.e(
        'WatchParty: createRoom failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    return room;
  }

  /// Every room this couple can see, newest activity first. Two queries
  /// (host side and partner side) are merged here because Firestore has
  /// no OR across different fields.
  Stream<List<WatchPartyRoom>> getRoomsStream(String uid) {
    if (_isDemo) {
      _seedDemo(uid, 'agent_demo_partner_uid');
      return Stream<List<WatchPartyRoom>>.multi((controller) {
        controller.add(_demoList());
        final sub = _demoRoomChanges.stream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    final hostQuery = _db
        .collection(_collection)
        .where('hostUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots();
    final partnerQuery = _db
        .collection(_collection)
        .where('partnerUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots();

    return _mergeRoomStreams(hostQuery, partnerQuery);
  }

  /// One-shot room list, used when a poster starts a party and we need to
  /// know whether a room is already live.
  Future<List<WatchPartyRoom>> getRooms(String uid) async {
    if (_isDemo) {
      _seedDemo(uid, 'agent_demo_partner_uid');
      return _demoList();
    }
    final results = await Future.wait([
      withGetTimeout(
        _db
            .collection(_collection)
            .where('hostUid', isEqualTo: uid)
            .orderBy('updatedAt', descending: true)
            .limit(20)
            .get(),
        label: 'watch party rooms (host)',
      ),
      withGetTimeout(
        _db
            .collection(_collection)
            .where('partnerUid', isEqualTo: uid)
            .orderBy('updatedAt', descending: true)
            .limit(20)
            .get(),
        label: 'watch party rooms (partner)',
      ),
    ]);
    final byId = <String, WatchPartyRoom>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        try {
          final room = WatchPartyRoom.fromFirestore(doc);
          byId[room.id] = room;
        } catch (e) {
          debugPrint('WatchPartyService.getRooms parse error: $e');
        }
      }
    }
    final rooms = byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rooms;
  }

  Stream<List<WatchPartyRoom>> _mergeRoomStreams(
    Stream<QuerySnapshot<Map<String, dynamic>>> a,
    Stream<QuerySnapshot<Map<String, dynamic>>> b,
  ) {
    late StreamController<List<WatchPartyRoom>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;
    List<WatchPartyRoom>? latestA;
    List<WatchPartyRoom>? latestB;

    List<WatchPartyRoom> merge() {
      final byId = <String, WatchPartyRoom>{};
      for (final room in [...?latestA, ...?latestB]) {
        byId[room.id] = room;
      }
      return byId.values.toList()
        ..sort((x, y) => y.updatedAt.compareTo(x.updatedAt));
    }

    void emit() {
      if (latestA == null || latestB == null) return;
      controller.add(merge());
    }

    List<WatchPartyRoom> parse(QuerySnapshot<Map<String, dynamic>> snap) {
      final rooms = <WatchPartyRoom>[];
      for (final doc in snap.docs) {
        try {
          rooms.add(WatchPartyRoom.fromFirestore(doc));
        } catch (e) {
          debugPrint('WatchPartyService room parse error: $e');
        }
      }
      return rooms;
    }

    controller = StreamController<List<WatchPartyRoom>>(
      onListen: () {
        subA = a.listen(
          (snap) {
            latestA = parse(snap);
            emit();
          },
          onError: controller.addError,
        );
        subB = b.listen(
          (snap) {
            latestB = parse(snap);
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  /// Live snapshot of a room. Emits `null` when the doc doesn't exist
  /// (e.g. the partner hasn't opened the sheet yet), otherwise the
  /// parsed [WatchPartyRoom].
  Stream<WatchPartyRoom?> getRoomStream(String roomId) {
    if (_isDemo) {
      return Stream<WatchPartyRoom?>.multi((controller) {
        controller.add(_demoRooms[roomId]);
        final sub = _demoRoomChanges.stream.listen((rooms) {
          for (final room in rooms) {
            if (room.id == roomId) {
              controller.add(room);
              return;
            }
          }
          controller.add(null);
        });
        controller.onCancel = sub.cancel;
      });
    }
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
    if (_isDemo) return _demoRooms[roomId];
    final snap = await withGetTimeout(
      _db.collection(_collection).doc(roomId).get(),
      label: 'watch party room',
    );
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
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(
        room.copyWith(
          state: state,
          currentTime: currentTime,
          positionAt: DateTime.now(),
          updatedAt: DateTime.now(),
          updatedBy: updatedBy,
          active: true,
        ),
      );
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).update({
        'state': state,
        'currentTime': currentTime,
        'positionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        'active': true,
      });
    } catch (e) {
      debugPrint('WatchPartyService.updatePlayback failed: $e');
      // Don't rethrow — a dropped heartbeat shouldn't crash the
      // player. The next tick (5s later) will succeed.
    }
  }

  /// Cheap "I'm still here" tick, written every few seconds by the
  /// host. It only carries the playback position (and keeps the room
  /// looking alive). It deliberately does NOT write `state`: if Clair
  /// pauses a moment before a tick lands, the tick must not flip the
  /// room back to "playing".
  Future<void> heartbeat({
    required String roomId,
    required String beatBy,
  }) async {
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(room.copyWith(beatBy: beatBy, updatedAt: DateTime.now()));
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).update({
        'updatedAt': FieldValue.serverTimestamp(),
        'beatBy': beatBy,
      });
    } catch (e, st) {
      Logger.e(
        'WatchParty: heartbeat write failed for $roomId',
        error: e,
        stackTrace: st,
      );
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
    int? episodeCount,
    required String title,
    required String posterPath,
    required String updatedBy,
  }) async {
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(
        room.copyWith(
          mediaType: mediaType,
          tmdbId: tmdbId,
          malId: malId,
          isAnime: isAnime,
          season: season,
          episode: episode,
          episodeCount: episodeCount,
          title: title,
          posterPath: posterPath,
          state: 'paused',
          currentTime: 0.0,
          positionAt: DateTime.now(),
          updatedAt: DateTime.now(),
          updatedBy: updatedBy,
          active: true,
        ).copyWithServer(
          serverType: 'everglow',
          serverName: 'Everglow',
          serverHost: 'everglow',
        ),
      );
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).update({
        'mediaType': mediaType,
        'tmdbId': tmdbId,
        'malId': malId ?? FieldValue.delete(),
        'season': season ?? FieldValue.delete(),
        'episode': episode ?? FieldValue.delete(),
        'episodeCount': episodeCount ?? FieldValue.delete(),
        'isAnime': isAnime,
        'title': title,
        'posterPath': posterPath,
        'serverType': 'everglow',
        'serverName': 'Everglow',
        'serverHost': 'everglow',
        'streamUrl': FieldValue.delete(),
        'subtitleUrl': FieldValue.delete(),
        'captionsOn': true,
        'proxyEnabled': false,
        'state': 'paused',
        'currentTime': 0.0,
        'positionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        'active': true,
      });
    } catch (e, st) {
      Logger.e(
        'WatchParty: updateMedia failed for $roomId',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Move the room to another episode without ending the party. The
  /// partner follows on the next snapshot. Playback restarts at 0 so you
  /// both land on the same frame. Everglow rebuilds the stream from the
  /// room's media identity; a fixed-URL HLS server reloads in place.
  Future<void> updateEpisode({
    required String roomId,
    required int season,
    required int episode,
    required String updatedBy,
  }) async {
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(
        room
            .copyWith(
              season: season,
              episode: episode,
              state: 'paused',
              currentTime: 0.0,
              positionAt: DateTime.now(),
              updatedAt: DateTime.now(),
              updatedBy: updatedBy,
            )
            .copyWithCaptions(subtitleUrl: null, captionsOn: true),
      );
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).update({
        'season': season,
        'episode': episode,
        'subtitleUrl': FieldValue.delete(),
        'captionsOn': true,
        'state': 'paused',
        'currentTime': 0.0,
        'positionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } catch (e, st) {
      Logger.e(
        'WatchParty: updateEpisode failed for $roomId',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Sync the caption choice. A null [subtitleUrl] means captions off.
  Future<void> updateCaptions({
    required String roomId,
    required String? subtitleUrl,
    required bool captionsOn,
    required String updatedBy,
  }) async {
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(
        room
            .copyWithCaptions(
              subtitleUrl: subtitleUrl,
              captionsOn: captionsOn,
            )
            .copyWith(updatedAt: DateTime.now(), updatedBy: updatedBy),
      );
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).update({
        'subtitleUrl': subtitleUrl ?? FieldValue.delete(),
        'captionsOn': captionsOn,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } catch (e, st) {
      Logger.e(
        'WatchParty: updateCaptions failed for $roomId',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Re-open an idle room (a named room you keep for movie nights).
  Future<void> reopenRoom({
    required String roomId,
    required String updatedBy,
  }) async {
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(
        room.copyWith(
          active: true,
          state: 'paused',
          updatedAt: DateTime.now(),
          updatedBy: updatedBy,
        ),
      );
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).update({
        'active': true,
        'state': 'paused',
        'positionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } catch (e, st) {
      Logger.e(
        'WatchParty: reopenRoom failed for $roomId',
        error: e,
        stackTrace: st,
      );
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
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(
        room.copyWith(
          state: 'paused',
          currentTime: 0.0,
          positionAt: DateTime.now(),
          updatedAt: DateTime.now(),
          updatedBy: updatedBy,
        ).copyWithServer(
          serverType: serverType,
          serverName: serverName,
          serverHost: serverHost,
          streamUrl: streamUrl,
          subtitleUrl: subtitleUrl,
          proxyEnabled: proxyEnabled,
        ),
      );
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).update({
        'serverType': serverType ?? FieldValue.delete(),
        'serverName': serverName ?? FieldValue.delete(),
        'serverHost': serverHost ?? FieldValue.delete(),
        'streamUrl': streamUrl ?? FieldValue.delete(),
        'subtitleUrl': subtitleUrl ?? FieldValue.delete(),
        'captionsOn': true,
        'proxyEnabled': proxyEnabled,
        'state': 'paused',
        'currentTime': 0.0,
        'positionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(
        room.copyWith(
          state: 'paused',
          currentTime: 0.0,
          positionAt: DateTime.now(),
          updatedAt: DateTime.now(),
          updatedBy: updatedBy,
        ).copyWithServer(),
      );
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).update({
        'serverType': FieldValue.delete(),
        'serverName': FieldValue.delete(),
        'serverHost': FieldValue.delete(),
        'streamUrl': FieldValue.delete(),
        'subtitleUrl': FieldValue.delete(),
        'captionsOn': true,
        'proxyEnabled': false,
        'state': 'paused',
        'currentTime': 0.0,
        'positionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(
        room.copyWith(
          active: false,
          state: 'paused',
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).update({
        'active': false,
        'state': 'paused',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('WatchPartyService.endRoom failed: $e');
    }
  }

  /// Hard-delete a room doc. Used for cleanup if both users have
  /// bounced and we want to start fresh.
  Future<void> deleteRoom(String roomId) async {
    if (_isDemo) {
      _demoRooms.remove(roomId);
      _demoRoomChanges.add(_demoList());
      return;
    }
    try {
      await _db.collection(_collection).doc(roomId).delete();
    } catch (e) {
      debugPrint('WatchPartyService.deleteRoom failed: $e');
    }
  }
}
