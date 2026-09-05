import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/date_randomizer/data/models/date_idea.dart';

void main() {
  group('DateIdea', () {
    test('fromFirestore reads id and title', () {
      final idea = DateIdea.fromFirestore({'title': 'Picnic'}, 'doc1');

      expect(idea.id, 'doc1');
      expect(idea.title, 'Picnic');
    });

    test('fromFirestore defaults a missing title to empty', () {
      final idea = DateIdea.fromFirestore({}, 'doc2');

      expect(idea.id, 'doc2');
      expect(idea.title, isEmpty);
    });

    test('toMap keeps the title', () {
      expect(DateIdea(id: 'd', title: 'Cinema').toMap(), {'title': 'Cinema'});
    });
  });
}
