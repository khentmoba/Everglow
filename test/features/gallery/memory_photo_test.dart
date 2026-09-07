import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/gallery/domain/models/memory_photo.dart';

MemoryPhoto _photo() => MemoryPhoto(
      id: 'p1',
      imageUrl: 'http://img/photo.jpg',
      caption: 'Sunset at the beach',
      uploadedBy: 'clair',
      uploadedAt: DateTime.utc(2026, 9, 1, 18),
      tags: const ['beach'],
      latitude: 14.5,
      longitude: 120.9,
      locationName: 'Batangas',
      takenAt: DateTime.utc(2026, 9, 1, 17, 45),
    );

void main() {
  group('MemoryPhoto', () {
    test('hasLocation needs both coordinates', () {
      expect(_photo().hasLocation, isTrue);
      expect(_photo().copyWith(clearLocation: true).hasLocation, isFalse);
      expect(
        MemoryPhoto(
          id: 'p2',
          imageUrl: 'u',
          caption: 'c',
          uploadedBy: 'khent',
          uploadedAt: DateTime.utc(2026, 9, 1),
          latitude: 14.5,
        ).hasLocation,
        isFalse,
      );
    });

    test('toFirestore keeps geo fields only when set', () {
      final map = _photo().toFirestore();

      expect(map['latitude'], 14.5);
      expect(map['longitude'], 120.9);
      expect(map['locationName'], 'Batangas');
      expect(map['tags'], ['beach']);

      final plain = MemoryPhoto(
        id: 'p3',
        imageUrl: 'u',
        caption: 'c',
        uploadedBy: 'khent',
        uploadedAt: DateTime.utc(2026, 9, 1),
      ).toFirestore();

      expect(plain.containsKey('latitude'), isFalse);
      expect(plain.containsKey('longitude'), isFalse);
      expect(plain.containsKey('locationName'), isFalse);
      expect(plain.containsKey('takenAt'), isFalse);
    });

    test('copyWith clears the whole location only when asked', () {
      final base = _photo();

      expect(base.copyWith().latitude, 14.5);
      expect(base.copyWith().locationName, 'Batangas');
      final cleared = base.copyWith(clearLocation: true);
      expect(cleared.latitude, isNull);
      expect(cleared.longitude, isNull);
      expect(cleared.locationName, isNull);
      expect(cleared.caption, base.caption);
      expect(cleared.takenAt, base.takenAt);
    });

    test('fromMap reads every field', () {
      final photo = MemoryPhoto.fromMap(
        {
          'imageUrl': 'u',
          'caption': 'c',
          'uploadedBy': 'clair',
          'uploadedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
          'tags': ['beach'],
          'latitude': 14.5,
          'longitude': 120.9,
        },
        id: 'p9',
      );

      expect(photo.id, 'p9');
      expect(photo.caption, 'c');
      expect(photo.tags, ['beach']);
      expect(photo.hasLocation, isTrue);
    });

    test('fromMap never crashes on odd field types', () {
      final photo = MemoryPhoto.fromMap({
        'imageUrl': null,
        'caption': null,
        'uploadedBy': null,
        'uploadedAt': null,
        'tags': 'beach',
        'latitude': '14.5',
        'longitude': 'nope',
      });

      expect(photo.imageUrl, isEmpty);
      expect(photo.caption, isEmpty);
      expect(photo.uploadedBy, isEmpty);
      expect(photo.uploadedAt, isA<DateTime>());
      expect(photo.tags, isEmpty);
      expect(photo.latitude, 14.5);
      expect(photo.longitude, isNull);
      expect(photo.hasLocation, isFalse);
    });
  });
}
