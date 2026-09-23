import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/dashboard/domain/models/milestone.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Milestone Model', () {
    test('should create a Milestone instance from data', () {
      final date = DateTime(2026, 2, 14);
      final milestone = Milestone(
        id: '1',
        title: 'First Date',
        description: 'Coffee at the park',
        date: date,
        imageUrls: ['https://example.com/image.jpg'],
        author: 'Khent',
      );

      expect(milestone.id, '1');
      expect(milestone.title, 'First Date');
      expect(milestone.description, 'Coffee at the park');
      expect(milestone.date, date);
      expect(milestone.imageUrls, ['https://example.com/image.jpg']);
      expect(milestone.author, 'Khent');
    });

    test('toFirestore should return correct map', () {
      final date = DateTime(2026, 2, 14);
      final milestone = Milestone(
        id: '1',
        title: 'First Date',
        description: 'Coffee at the park',
        date: date,
        imageUrls: ['https://example.com/image.jpg'],
        author: 'Khent',
      );

      final map = milestone.toFirestore();

      expect(map['title'], 'First Date');
      expect(map['description'], 'Coffee at the park');
      expect(map['date'], isA<Timestamp>());
      expect(map['imageUrls'], ['https://example.com/image.jpg']);
      expect(map['author'], 'Khent');
    });
  });
}
