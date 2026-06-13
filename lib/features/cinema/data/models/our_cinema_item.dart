import 'package:cloud_firestore/cloud_firestore.dart';

/// A single entry in the shared "Our Cinema" list, visible to Khent and Clair.
///
/// Stored in the `our_cinema` Firestore collection. We track each partner's
/// watched timestamp independently so we can derive the composite status
/// (`to-watch` / `watched-khent` / `watched-clair` / `watched-both`).
class OurCinemaItem {
  final String id;
  final int tmdbId;
  final String title;
  final String mediaType;
  final String posterPath;
  final String backdropPath;
  final String year;

  /// Which partner added the item to the shared list.
  /// Always one of 'khentsgdz' or 'clairjassen'.
  final String addedBy;

  final DateTime addedAt;

  /// `null` means Khent has not watched it yet.
  final DateTime? khentWatchedAt;

  /// `null` means Clair has not watched it yet.
  final DateTime? clairWatchedAt;

  const OurCinemaItem({
    required this.id,
    required this.tmdbId,
    required this.title,
    required this.mediaType,
    required this.posterPath,
    this.backdropPath = '',
    this.year = '',
    required this.addedBy,
    required this.addedAt,
    this.khentWatchedAt,
    this.clairWatchedAt,
  });

  /// Composite status string the UI renders.
  String get status {
    final k = khentWatchedAt != null;
    final c = clairWatchedAt != null;
    if (k && c) return 'watched-both';
    if (k) return 'watched-khent';
    if (c) return 'watched-clair';
    return 'to-watch';
  }

  bool get isWatched => khentWatchedAt != null || clairWatchedAt != null;
  bool get isWatchedByKhent => khentWatchedAt != null;
  bool get isWatchedByClair => clairWatchedAt != null;

  /// Human-readable label for the composite status.
  String get statusLabel {
    switch (status) {
      case 'watched-both':
        return 'Watched by Both';
      case 'watched-khent':
        return 'Watched by Khent';
      case 'watched-clair':
        return 'Watched by Clair';
      default:
        return 'To Watch Together';
    }
  }

  factory OurCinemaItem.fromFirestore(
      Map<String, dynamic> data, String documentId) {
    return OurCinemaItem(
      id: documentId,
      tmdbId: data['tmdbId'] ?? 0,
      title: data['title'] ?? '',
      mediaType: data['mediaType'] ?? 'movie',
      posterPath: data['posterPath'] ?? '',
      backdropPath: data['backdropPath'] ?? '',
      year: data['year'] ?? '',
      addedBy: data['addedBy'] ?? '',
      addedAt: _parseDateTime(data['addedAt']),
      khentWatchedAt: _parseNullableDateTime(data['khentWatchedAt']),
      clairWatchedAt: _parseNullableDateTime(data['clairWatchedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tmdbId': tmdbId,
      'title': title,
      'mediaType': mediaType,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'year': year,
      'addedBy': addedBy,
      'addedAt': Timestamp.fromDate(addedAt),
      'khentWatchedAt':
          khentWatchedAt == null ? null : Timestamp.fromDate(khentWatchedAt!),
      'clairWatchedAt':
          clairWatchedAt == null ? null : Timestamp.fromDate(clairWatchedAt!),
    };
  }

  OurCinemaItem copyWith({
    String? id,
    int? tmdbId,
    String? title,
    String? mediaType,
    String? posterPath,
    String? backdropPath,
    String? year,
    String? addedBy,
    DateTime? addedAt,
    DateTime? khentWatchedAt,
    DateTime? clairWatchedAt,
    bool clearKhentWatched = false,
    bool clearClairWatched = false,
  }) {
    return OurCinemaItem(
      id: id ?? this.id,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      year: year ?? this.year,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      khentWatchedAt: clearKhentWatched ? null : (khentWatchedAt ?? this.khentWatchedAt),
      clairWatchedAt: clearClairWatched ? null : (clairWatchedAt ?? this.clairWatchedAt),
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

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
