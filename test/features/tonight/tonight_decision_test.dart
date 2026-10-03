import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/features/tonight/data/models/tonight_option.dart';
import 'package:everglow/features/tonight/data/models/tonight_decision.dart';

void main() {
  group('TonightDecision Model', () {
    final sampleOptions = [
      const TonightOption(
        id: 'opt_1',
        type: TonightOptionType.movie,
        title: 'Movie Night',
      ),
      const TonightOption(
        id: 'opt_2',
        type: TonightOptionType.date,
        title: 'Candlelight Pasta',
      ),
      const TonightOption(
        id: 'opt_3',
        type: TonightOptionType.game,
        title: 'Table Tennis',
      ),
    ];

    test('parses full decision and detects match', () {
      final now = DateTime.now();
      final map = {
        'status': 'decided',
        'options': sampleOptions.map((o) => o.toMap()).toList(),
        'votes': {'khentsgdz': 'opt_1', 'clairjassen': 'opt_1'},
        'winnerOptionId': 'opt_1',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final decision = TonightDecision.fromMap(map, 'active');

      expect(decision.id, 'active');
      expect(decision.status, TonightStatus.decided);
      expect(decision.options.length, 3);
      expect(decision.votes['khentsgdz'], 'opt_1');
      expect(decision.votes['clairjassen'], 'opt_1');
      expect(decision.isMatch, isTrue);
      expect(decision.hasBothVoted, isTrue);
      expect(decision.isTied, isFalse);
      expect(decision.winningOption?.title, 'Movie Night');
    });

    test('detects tied votes when partner votes differ', () {
      final now = DateTime.now();
      final map = {
        'status': 'voting',
        'options': sampleOptions.map((o) => o.toMap()).toList(),
        'votes': {'khentsgdz': 'opt_1', 'clairjassen': 'opt_3'},
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final decision = TonightDecision.fromMap(map, 'active');

      expect(decision.isMatch, isFalse);
      expect(decision.hasBothVoted, isTrue);
      expect(decision.isTied, isTrue);
      expect(decision.khentVote, 'opt_1');
      expect(decision.clairVote, 'opt_3');
    });

    test('handles single vote state', () {
      final now = DateTime.now();
      final map = {
        'status': 'voting',
        'options': sampleOptions.map((o) => o.toMap()).toList(),
        'votes': {'khentsgdz': 'opt_2'},
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final decision = TonightDecision.fromMap(map, 'active');

      expect(decision.isMatch, isFalse);
      expect(decision.hasBothVoted, isFalse);
      expect(decision.isTied, isFalse);
      expect(decision.khentVote, 'opt_2');
      expect(decision.clairVote, isNull);
    });

    test('tolerates hostile stored data and null values safely', () {
      final decision = TonightDecision.fromMap(null);
      expect(decision.id, 'active');
      expect(decision.status, TonightStatus.voting);
      expect(decision.options, isEmpty);
      expect(decision.votes, isEmpty);

      final decisionCorrupted = TonightDecision.fromMap({
        'status': 'invalid_status_string',
        'options': [
          {123: 'invalid-key', 'id': 'valid-option', 'title': 'Safe'},
        ],
        'votes': 99999,
        'winnerOptionId': null,
        'createdAt': 'invalid_date',
        'updatedAt': null,
      }, 'corrupt_doc');

      expect(decisionCorrupted.id, 'corrupt_doc');
      expect(decisionCorrupted.status, TonightStatus.voting);
      expect(decisionCorrupted.options.single.title, 'Safe');
      expect(decisionCorrupted.votes, isEmpty);
    });
  });
}
