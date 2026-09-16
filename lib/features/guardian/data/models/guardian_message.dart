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
      content: _toStr(data['content']),
      category: _toStr(data['category'], fallback: 'idle'),
      createdAt: _toDate(data['createdAt']),
    );
  }

  static String _toStr(dynamic value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'category': category,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
