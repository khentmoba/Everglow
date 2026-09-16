import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/jukebox/data/models/jukebox_dedication.dart';

void main() {
  group('JukeboxDedication', () {
    test('fromMap reads every field', () {
      final created = DateTime.utc(2026, 9, 12, 20);
      final dedication = JukeboxDedication.fromMap('d1', {
        'fromUsername': 'khentsgdz',
        'toUsername': 'clairjassen',
        'trackName': 'Photograph',
        'artistName': 'Ed Sheeran',
        'imageUrl': 'https://img/cover.jpg',
        'message': 'This one is us',
        'createdAt': Timestamp.fromDate(created),
      });

      expect(dedication.id, 'd1');
      expect(dedication.fromUsername, 'khentsgdz');
      expect(dedication.toUsername, 'clairjassen');
      expect(dedication.trackName, 'Photograph');
      expect(dedication.artistName, 'Ed Sheeran');
      expect(dedication.imageUrl, 'https://img/cover.jpg');
      expect(dedication.message, 'This one is us');
      expect(dedication.createdAt.millisecondsSinceEpoch,
          created.millisecondsSinceEpoch);
    });

    test('toMap round-trips through fromMap', () {
      final original = JukeboxDedication(
        id: 'd2',
        fromUsername: 'clairjassen',
        toUsername: 'khentsgdz',
        trackName: 'All of Me',
        artistName: 'John Legend',
        createdAt: DateTime.utc(2026, 9, 12),
      );
      final restored = JukeboxDedication.fromMap('d2', original.toMap());

      expect(restored.trackName, 'All of Me');
      expect(restored.imageUrl, isNull);
      expect(restored.message, isNull);
      expect(restored.createdAt.millisecondsSinceEpoch,
          original.createdAt.millisecondsSinceEpoch);
    });

    test('fromMap never crashes on odd field types', () {
      final dedication = JukeboxDedication.fromMap('d3', {
        'fromUsername': 1,
        'toUsername': ['clair'],
        'trackName': 42,
        'artistName': true,
        'imageUrl': 7,
        'message': {'text': 'hi'},
        'createdAt': 'not-a-date',
      });

      expect(dedication.fromUsername, isEmpty);
      expect(dedication.toUsername, isEmpty);
      expect(dedication.trackName, isEmpty);
      expect(dedication.artistName, isEmpty);
      expect(dedication.imageUrl, isNull);
      expect(dedication.message, isNull);
      expect(dedication.createdAt, isA<DateTime>());
    });
  });
}
