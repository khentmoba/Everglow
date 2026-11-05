// SDK sealed types are implemented only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/services/presence_service.dart';
import 'package:everglow/core/system/health_service.dart';
import 'package:everglow/features/xp/data/services/xp_service.dart';
import 'package:everglow/shared/utils/tmdb_images.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Records every touch, so an error swallowed inside a service still fails.
class _LiveFirestore implements FirebaseFirestore {
  bool touched = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    touched = true;
    throw StateError('Touched live Firestore: ${invocation.memberName}');
  }
}

void main() {
  const uid = 'agent_khentsgdz_uid';
  late _LiveFirestore db;

  setUp(() {
    db = _LiveFirestore();
    AgentMode.isActive.value = true;
    AgentMode.useDemoData.value = true;
  });

  tearDown(() => AgentMode.isActive.value = false);

  test('demo presence never reads or writes live presence documents', () async {
    final presence = PresenceService(firestore: db);

    expect((await presence.watchPresence(uid).first).uid, uid);
    presence.startHeartbeat(uid: uid, username: 'khentsgdz');
    await presence.setOnline(uid: uid, username: 'khentsgdz');
    await presence.setOffline(uid);
    await presence.markDoodling(uid);
    await presence.clearDoodling(uid);
    await presence.stopHeartbeat();

    expect(db.touched, isFalse);
  });

  test('control: presence still reads Firestore outside demo', () {
    AgentMode.isActive.value = false;
    final presence = PresenceService(firestore: db);

    expect(() => presence.watchPresence(uid), throwsStateError);
    expect(db.touched, isTrue);
  });

  test('demo XP shows a fixture and writes nothing', () async {
    final xp = XPService.withFirestore(db);

    expect((await xp.watchProgress(uid).first)?.xpTotal, 420);
    expect(await xp.awardMood(uid), isFalse);
    await xp.addXp(uid, 10);
    await xp.initializeProgress(uid);

    expect(db.touched, isFalse);
  });

  test('demo health probe does not call the production backend', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response('{"status":"ok"}', 200);
    });
    final service = HealthService(
      client: client,
      endpoint: Uri.parse('https://everglow-1c6db.web.app/api/health'),
    );

    expect((await service.probe()).isHealthy, isTrue);
    expect(requests, isEmpty);
  });

  test('bundled demo artwork never gets the TMDB CDN prefix', () {
    const poster = 'assets/images/demo/poster-1.jpg';

    expect(TmdbImages.cardFor(poster), poster);
    expect(TmdbImages.posterFor(poster), poster);
    expect(TmdbImages.backdropFor(poster), poster);
  });
}
