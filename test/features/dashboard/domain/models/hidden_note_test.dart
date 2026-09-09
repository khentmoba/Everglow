import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/domain/models/hidden_note.dart';

void main() {
  group('HiddenNote.isUnlocked', () {
    test('returns true when unlockDate is in the past', () {
      final note = HiddenNote(
        id: '1',
        title: 'Old Letter',
        content: 'Hello!',
        unlockDate: DateTime(2020, 1, 1),
      );

      expect(note.isUnlocked, isTrue);
    });

    test('returns true when unlockDate equals now (same instant)', () {
      final now = DateTime.now();
      final note = HiddenNote(
        id: '2',
        title: 'Just Unlocked',
        content: 'Surprise!',
        unlockDate: now,
      );

      // isAtSameMomentAs should match
      expect(note.isUnlocked, isTrue);
    });

    test('returns false when unlockDate is in the future', () {
      final note = HiddenNote(
        id: '3',
        title: 'Future Letter',
        content: 'Wait for it...',
        unlockDate: DateTime(2100, 12, 31),
      );

      expect(note.isUnlocked, isFalse);
    });
  });

  group('HiddenNote defaults', () {
    test('isRead defaults to false', () {
      final note = HiddenNote(
        id: '1',
        title: 'Test',
        content: 'Content',
        unlockDate: DateTime(2025, 1, 1),
      );

      expect(note.isRead, isFalse);
    });

    test('isRead can be set to true', () {
      final note = HiddenNote(
        id: '1',
        title: 'Test',
        content: 'Content',
        unlockDate: DateTime(2025, 1, 1),
        isRead: true,
      );

      expect(note.isRead, isTrue);
    });
  });

  group('HiddenNote serialization', () {
    test('round-trips through toJson and fromJson', () {
      final original = HiddenNote(
        id: 'letter-42',
        title: 'A Love Note',
        content: 'I love you so much!',
        unlockDate: DateTime(2026, 9, 20, 15, 30),
        isRead: true,
      );

      final json = original.toJson();
      final restored = HiddenNote.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.content, equals(original.content));
      expect(restored.unlockDate, equals(original.unlockDate));
      expect(restored.isRead, isTrue);
    });

    test('fromJson handles nulls and missing fields gracefully', () {
      final restored = HiddenNote.fromJson({});

      expect(restored.id, isEmpty);
      expect(restored.title, isEmpty);
      expect(restored.content, isEmpty);
      expect(restored.isRead, isFalse);
      expect(restored.unlockDate, isNotNull);
    });
  });
}
