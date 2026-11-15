import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';

import '../models/watch_party_room.dart';

class WatchPartyService {
  static const String _collection = 'watch_party_rooms';

  WatchPartyService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

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

  Future<WatchPartyRoom?> getRoom(String roomId) async {
    if (_isDemo) return _demoRooms[roomId];
    final snap = await withGetTimeout(
      _db.collection(_collection).doc(roomId).get(),
      label: 'watch party room',
    );
    if (!snap.exists) return null;
    return WatchPartyRoom.fromFirestore(snap);
  }

  Future<void> updatePlayback({
    required String roomId,
    required String state,
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
    }
  }

  Future<void> heartbeat({
    required String roomId,
    required String beatBy,
    double? currentTime,
  }) async {
    if (_isDemo) {
      final room = _demoRooms[roomId];
      if (room == null) return;
      _putDemo(
        room.copyWith(
          currentTime: currentTime,
          positionAt: currentTime == null ? null : DateTime.now(),
          beatBy: beatBy,
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'beatBy': beatBy,
      };
      if (currentTime != null) {
        data['currentTime'] = currentTime;
        data['positionAt'] = FieldValue.serverTimestamp();
      }
      await _db.collection(_collection).doc(roomId).update(data);
    } catch (e, st) {
      Logger.e(
        'WatchParty: heartbeat write failed for $roomId',
        error: e,
        stackTrace: st,
      );
    }
  }

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
        ).copyWithCaptions(subtitleUrl: null, captionsOn: true),
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
