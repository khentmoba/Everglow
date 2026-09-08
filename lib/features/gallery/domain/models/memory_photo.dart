import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryPhoto {
  final String id;
  final String imageUrl;
  final String caption;
  final String uploadedBy;
  final DateTime uploadedAt;
  final List<String> tags;

  // Phase 2 — Immich / HomeGallery inspired geolocation
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final DateTime? takenAt;

  const MemoryPhoto({
    required this.id,
    required this.imageUrl,
    required this.caption,
    required this.uploadedBy,
    required this.uploadedAt,
    this.tags = const [],
    this.latitude,
    this.longitude,
    this.locationName,
    this.takenAt,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory MemoryPhoto.fromFirestore(DocumentSnapshot doc) {
    return MemoryPhoto.fromMap(
      doc.data() as Map<String, dynamic>? ?? const {},
      id: doc.id,
    );
  }

  factory MemoryPhoto.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return MemoryPhoto(
      id: id,
      imageUrl: data['imageUrl'] as String? ?? '',
      caption: data['caption'] as String? ?? '',
      uploadedBy: data['uploadedBy'] as String? ?? '',
      uploadedAt: _parseTimestamp(data['uploadedAt']),
      tags: _parseTags(data['tags']),
      latitude: _parseCoord(data['latitude']),
      longitude: _parseCoord(data['longitude']),
      locationName: data['locationName'] as String?,
      takenAt: data['takenAt'] != null
          ? _parseTimestamp(data['takenAt'])
          : null,
    );
  }

  static List<String> _parseTags(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static double? _parseCoord(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationName != null) 'locationName': locationName,
      if (takenAt != null) 'takenAt': Timestamp.fromDate(takenAt!),
    };
  }

  MemoryPhoto copyWith({
    String? caption,
    List<String>? tags,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? takenAt,
    bool clearLocation = false,
  }) => MemoryPhoto(
    id: id,
    imageUrl: imageUrl,
    caption: caption ?? this.caption,
    uploadedBy: uploadedBy,
    uploadedAt: uploadedAt,
    tags: tags ?? this.tags,
    latitude: clearLocation ? null : (latitude ?? this.latitude),
    longitude: clearLocation ? null : (longitude ?? this.longitude),
    locationName: clearLocation ? null : (locationName ?? this.locationName),
    takenAt: takenAt ?? this.takenAt,
  );
}
