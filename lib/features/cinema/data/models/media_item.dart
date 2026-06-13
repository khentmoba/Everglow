import 'package:cloud_firestore/cloud_firestore.dart';

class MediaItem {
  final String id;
  final int tmdbId;
  final String title;
  final String mediaType;
  final String posterPath;
  final String backdropPath;
  final String year;
  final String status;

  /// Owning user. Items in `watch_list` are scoped per user so Khent, Clair,
  /// and Breyan each see only their own queue / watched history.
  final String userName;
  final DateTime addedAt;

  MediaItem({
    required this.id,
    required this.tmdbId,
    required this.title,
    required this.mediaType,
    required this.posterPath,
    this.backdropPath = '',
    this.year = '',
    required this.status,
    this.userName = '',
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
      backdropPath: data['backdropPath'] ?? '',
      year: data['year'] ?? '',
      status: data['status'] ?? 'to-watch',
      userName: data['userName'] ?? '',
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
      'backdropPath': backdropPath,
      'year': year,
      'status': status,
      'userName': userName,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  MediaItem copyWith({
    String? id,
    int? tmdbId,
    String? title,
    String? mediaType,
    String? posterPath,
    String? backdropPath,
    String? year,
    String? status,
    String? userName,
    DateTime? addedAt,
  }) {
    return MediaItem(
      id: id ?? this.id,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      year: year ?? this.year,
      status: status ?? this.status,
      userName: userName ?? this.userName,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
