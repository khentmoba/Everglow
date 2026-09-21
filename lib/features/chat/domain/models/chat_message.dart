import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String sender;
  final String senderUid;
  final String text;
  final DateTime timestamp;
  final bool isOptimistic;
  final bool isFailed;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.senderUid,
    required this.text,
    required this.timestamp,
    this.isOptimistic = false,
    this.isFailed = false,
  });

  ChatMessage copyWith({
    String? id,
    String? sender,
    String? senderUid,
    String? text,
    DateTime? timestamp,
    bool? isOptimistic,
    bool? isFailed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      senderUid: senderUid ?? this.senderUid,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return ChatMessage(
      id: doc.id,
      sender: data['sender'] ?? '',
      senderUid: data['senderUid'] ?? '',
      text: data['text'] ?? '',
      timestamp: parseTimestamp(data['timestamp']),
    );
  }

  static DateTime parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    return {
      'sender': sender,
      'senderUid': senderUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'monthDay': '$m-$d',
    };
  }
}
