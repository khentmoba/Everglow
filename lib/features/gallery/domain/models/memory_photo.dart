import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryPhoto {
  final String id;
  final String imageUrl;
  final String caption;
  final String uploadedBy;
  final DateTime uploadedAt;
  final List<String> tags;

  const MemoryPhoto({
    required this.id,
    required this.imageUrl,
    required this.caption,
    required this.uploadedBy,
    required this.uploadedAt,
    this.tags = const [],
  });

  factory MemoryPhoto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MemoryPhoto(
      id: doc.id,
      imageUrl: data['imageUrl'] ?? '',
      caption: data['caption'] ?? '',
      uploadedBy: data['uploadedBy'] ?? '',
      uploadedAt: _parseTimestamp(data['uploadedAt']),
      tags:
          (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
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

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'caption': caption,
      'uploadedBy': uploadedBy,
      'uploadedAt': FieldValue.serverTimestamp(),
      'tags': tags,
    };
  }
}
