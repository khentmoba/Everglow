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
    final data = doc.data() as Map<String, dynamic>? ?? {};
    // Safe parsing: missing or malformed unlockDate falls back to now (unlocked)
    // so the letter is at least visible rather than crashing the whole stream.
    DateTime unlockDate;
    final rawDate = data['unlockDate'];
    if (rawDate is Timestamp) {
      unlockDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      unlockDate = rawDate;
    } else {
      unlockDate = DateTime.now();
    }

    final rawRead = data['isRead'];
    final isRead = rawRead is bool ? rawRead : false;

    return HiddenNote(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      unlockDate: unlockDate,
      isRead: isRead,
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