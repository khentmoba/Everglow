// Network-free SDK boundary; no emulator is needed for room write semantics.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/watch_party/data/services/watch_party_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Db implements FirebaseFirestore {
  Map<String, dynamic> room = {};
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Rooms(this);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rooms implements CollectionReference<Map<String, dynamic>> {
  final _Db db;
  _Rooms(this.db);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _Room(db);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Room implements DocumentReference<Map<String, dynamic>> {
  final _Db db;
  _Room(this.db);
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (options?.merge != true) db.room.clear();
    db.room.addAll(data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    for (final entry in data.entries) {
      if (entry.value == FieldValue.delete()) {
        db.room.remove(entry.key);
      } else {
        db.room[entry.key as String] = entry.value;
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'a new movie night removes the old stream, subtitles and episode',
    () async {
      final db = _Db()
        ..room = {
          'serverType': 'hls',
          'serverName': 'Old server',
          'serverHost': 'old.example',
          'streamUrl': 'https://old.example/movie.m3u8',
          'subtitleUrl': 'https://old.example/sub.vtt',
          'season': 4,
          'episode': 8,
          'malId': 42,
          'beatBy': 'old-host',
          'active': false,
        };
      final service = WatchPartyService(db: db);
      final started = await service.startRoom(
        hostUid: 'khent-demo',
        hostName: 'Khent',
        partnerUid: 'clair-demo',
        partnerName: 'Clair',
        mediaType: 'movie',
        tmdbId: 123,
        title: 'Demo movie',
        posterPath: '',
      );
      expect(db.room, started.toFirestore());
      expect(db.room['serverType'], isNull);
      expect(db.room['streamUrl'], isNull);
      expect(db.room['subtitleUrl'], isNull);
      expect(db.room['episode'], isNull);
      expect(db.room['active'], isTrue);
    },
  );

  test(
    'switching servers clears optional fields omitted by the new server',
    () async {
      final db = _Db()
        ..room = {
          'serverHost': 'old.example',
          'subtitleUrl': 'https://old.example/sub.vtt',
          'title': 'Demo movie',
        };
      await WatchPartyService(db: db).updateServer(
        roomId: 'demo',
        serverType: 'hls',
        serverName: 'New server',
        streamUrl: 'https://new.example/movie.m3u8',
        updatedBy: 'khent-demo',
      );
      expect(db.room['streamUrl'], 'https://new.example/movie.m3u8');
      expect(db.room.containsKey('subtitleUrl'), isFalse);
      expect(db.room.containsKey('serverHost'), isFalse);
      expect(db.room['title'], 'Demo movie');
      expect(db.room['state'], 'paused');
      expect(db.room['currentTime'], 0.0);
    },
  );
}
