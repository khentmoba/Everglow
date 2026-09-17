import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/ai/domain/models/mini_game.dart';

void main() {
  group('MiniGame', () {
    test('fromFirestore reads every field', () {
      final created = DateTime.utc(2026, 9, 17);
      final game = MiniGame.fromFirestore({
        'title': 'Checkers',
        'html': '<html>game</html>',
        'createdBy': 'khentsgdz',
        'createdAt': Timestamp.fromDate(created),
      }, 'g1');

      expect(game.id, 'g1');
      expect(game.title, 'Checkers');
      expect(game.html, '<html>game</html>');
      expect(game.createdBy, 'khentsgdz');
      expect(
        game.createdAt?.millisecondsSinceEpoch,
        created.millisecondsSinceEpoch,
      );
    });

    test('fromFirestore tolerates missing fields', () {
      final game = MiniGame.fromFirestore({}, 'g2');

      expect(game.id, 'g2');
      expect(game.title, isEmpty);
      expect(game.html, isEmpty);
      expect(game.createdBy, isEmpty);
      expect(game.createdAt, isNull);
    });

    test('fromFirestore never crashes on odd field types', () {
      final game = MiniGame.fromFirestore({
        'title': 42,
        'html': ['not', 'html'],
        'createdBy': 7,
        'createdAt': 'someday',
      }, 'g3');

      expect(game.title, isEmpty);
      expect(game.html, isEmpty);
      expect(game.createdBy, isEmpty);
      expect(game.createdAt, isNull);
    });
  });
}
