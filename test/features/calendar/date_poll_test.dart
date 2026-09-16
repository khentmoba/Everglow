import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/calendar/data/models/date_poll.dart';

void main() {
  group('DatePoll', () {
    test('fromMap reads options, votes and decision', () {
      final created = DateTime.utc(2026, 9, 10);
      final poll = DatePoll.fromMap({
        'title': 'Anniversary dinner',
        'description': 'Pick a night',
        'createdBy': 'khentsgdz',
        'createdAt': Timestamp.fromDate(created),
        'options': [
          {
            'id': 'o1',
            'date': Timestamp.fromDate(DateTime.utc(2026, 9, 20, 19)),
            'label': 'Sat, Sep 20 — 7pm',
          },
        ],
        'votes': {'khentsgdz': 'o1', 'clairjassen': 'o1'},
        'status': 'closed',
        'decidedOptionId': 'o1',
      }, 'poll1');

      expect(poll.id, 'poll1');
      expect(poll.title, 'Anniversary dinner');
      expect(poll.options, hasLength(1));
      expect(poll.options.first.label, 'Sat, Sep 20 — 7pm');
      expect(poll.tally, {'o1': 2});
      expect(poll.winningOptionId, 'o1');
      expect(poll.isTie, isFalse);
      expect(poll.status, PollStatus.closed);
      expect(poll.decidedOptionId, 'o1');
    });

    test('fromMap never crashes on odd field types', () {
      final poll = DatePoll.fromMap({
        'title': 5,
        'description': ['x'],
        'createdBy': 7,
        'createdAt': 'not-a-date',
        'options': 'o1',
        'votes': ['khentsgdz'],
        'status': 42,
        'decidedOptionId': 9,
      }, 'poll2');

      expect(poll.title, isEmpty);
      expect(poll.description, isEmpty);
      expect(poll.createdBy, isEmpty);
      expect(poll.createdAt, isA<DateTime>());
      expect(poll.options, isEmpty);
      expect(poll.votes, isEmpty);
      expect(poll.status, PollStatus.open);
      expect(poll.decidedOptionId, isNull);
      expect(poll.winningOptionId, isNull);
    });

    test('fromMap skips broken options and votes', () {
      final poll = DatePoll.fromMap({
        'title': 'Movie night',
        'createdBy': 'clairjassen',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 10)),
        'options': [
          'o1',
          42,
          {'id': 'o2', 'date': 'not-a-date', 'label': 'Fri — 8pm'},
        ],
        'votes': {
          'khentsgdz': 'o2',
          'clairjassen': 7,
          9: 'o2',
        },
      }, 'poll3');

      expect(poll.options, hasLength(1));
      expect(poll.options.first.id, 'o2');
      expect(poll.options.first.date, isA<DateTime>());
      expect(poll.votes, {'khentsgdz': 'o2'});
    });
  });
}
