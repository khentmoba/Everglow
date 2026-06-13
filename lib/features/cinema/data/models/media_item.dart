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

  /// True for Japanese animation (anime). Auto-detected from TMDB details
  /// (original_language == 'ja' + Animation genre) when the title is saved
  /// to the watchlist. Powers the dedicated "Anime" rail and screen.
  final bool isAnime;

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
    this.isAnime = false,
    this.userName = '',
    required this.addedAt,
  });

  bool get isWatched =>
      status == 'watched' ||
      status == 'watched-khent' ||
      status == 'watched-clair' ||
      status == 'watched-both' ||
      status == 'watched-self';

  bool get isToWatch => status == 'to-watch';

  String get watchedDisplay {
    if (status == 'watched-khent') return 'Watched by Khent';
    if (status == 'watched-clair') return 'Watched by Clair';
    if (status == 'watched-both' || status == 'watched') return 'Watched by Both';
    if (status == 'watched-self') return 'Watched';
    return 'To Watch';
  }

  /// Returns the list of partner usernames (e.g. `['khentsgdz']`,
  /// `['clairjassen']`, or `['khentsgdz', 'clairjassen']`) by splitting the
  /// `userName` field on commas. Used to render the khent/clair/both
  /// attribution in the combined couple watchlist view.
  List<String> get partnerUsernames {
    return userName
        .split(',')
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
  }

  /// Short label for which partner(s) have the title in their queue.
  /// For a couple's combined wishlist this is rendered as the
  /// khent/clair/both chip in the grid.
  String get wanterDisplay {
    final partners = partnerUsernames;
    final hasKhent = partners.contains('khentsgdz');
    final hasClair = partners.contains('clairjassen');
    if (hasKhent && hasClair) return 'Both';
    if (hasKhent) return 'Khent';
    if (hasClair) return 'Clair';
    return 'Mine';
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
      isAnime: data['isAnime'] == true,
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
      'isAnime': isAnime,
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
    bool? isAnime,
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
      isAnime: isAnime ?? this.isAnime,
      userName: userName ?? this.userName,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
