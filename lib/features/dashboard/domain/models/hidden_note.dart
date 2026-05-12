import 'package:cloud_firestore/cloud_firestore.dart';

class HiddenNote {
  final String id;
  final String title;
  final String content;
  final DateTime unlockDate;
  bool isRead;

  HiddenNote({
    required this.id,
    required this.title,
    required this.content,
    required this.unlockDate,
    this.isRead = false,
  });

  bool get isUnlocked {
    final now = DateTime.now();
    return now.isAfter(unlockDate) || now.isAtSameMomentAs(unlockDate);
  }

  factory HiddenNote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return HiddenNote(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      unlockDate: (data['unlockDate'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'unlockDate': Timestamp.fromDate(unlockDate),
      'isRead': isRead,
    };
  }
}
