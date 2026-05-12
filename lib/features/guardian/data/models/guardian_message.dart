import 'package:cloud_firestore/cloud_firestore.dart';

class GuardianMessage {
  final String id;
  final String content;
  final String category;
  final DateTime? createdAt;

  GuardianMessage({
    required this.id,
    required this.content,
    required this.category,
    this.createdAt,
  });

  factory GuardianMessage.fromFirestore(Map<String, dynamic> data, String id) {
    return GuardianMessage(
      id: id,
      content: data['content'] ?? '',
      category: data['category'] ?? 'idle',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'category': category,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
