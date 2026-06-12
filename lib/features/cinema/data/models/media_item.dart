import 'package:cloud_firestore/cloud_firestore.dart';

class MediaItem {
  final String id;
  final int tmdbId;
  final String title;
  final String mediaType;
  final String posterPath;
  final String status;
  final DateTime addedAt;

  MediaItem({
    required this.id,
    required this.tmdbId,
    required this.title,
    required this.mediaType,
    required this.posterPath,
    required this.status,
    required this.addedAt,
  });

  bool get isWatched =>
      status == 'watched' ||
      status == 'watched-khent' ||
      status == 'watched-clair' ||
      status == 'watched-both';

  bool get isToWatch => status == 'to-watch';

  String get watchedDisplay {
    if (status == 'watched-khent') return 'Watched by Khent';
    if (status == 'watched-clair') return 'Watched by Clair';
    if (status == 'watched-both' || status == 'watched') return 'Watched by Both';
    return 'To Watch';
  }

  factory MediaItem.fromFirestore(Map<String, dynamic> data, String documentId) {
    return MediaItem(
      id: documentId,
      tmdbId: data['tmdbId'] ?? 0,
      title: data['title'] ?? '',
      mediaType: data['mediaType'] ?? 'movie',
      posterPath: data['posterPath'] ?? '',
      status: data['status'] ?? 'to-watch',
      addedAt: _parseDateTime(data['addedAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
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
      'tmdbId': tmdbId,
      'title': title,
      'mediaType': mediaType,
      'posterPath': posterPath,
      'status': status,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  MediaItem copyWith({
    String? id,
    int? tmdbId,
    String? title,
    String? mediaType,
    String? posterPath,
    String? status,
    DateTime? addedAt,
  }) {
    return MediaItem(
      id: id ?? this.id,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      posterPath: posterPath ?? this.posterPath,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
