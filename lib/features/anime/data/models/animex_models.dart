import '../../../cinema/data/models/media_item.dart';

/// Paginated result from AniList page queries used by the anime section.
/// Scores are kept aligned with [items] so grids can show ratings.
class AnimexMediaPage {
  final List<MediaItem> items;
  final List<double> scores;
  final int currentPage;
  final int? lastPage;
  final bool hasNextPage;

  const AnimexMediaPage({
    required this.items,
    required this.scores,
    required this.currentPage,
    this.lastPage,
    required this.hasNextPage,
  });

  bool get isEmpty => items.isEmpty;
}

/// One row of the weekly airing schedule.
class AnimexScheduleEntry {
  final MediaItem media;
  final int episode;
  final DateTime airingAt;

  const AnimexScheduleEntry({
    required this.media,
    required this.episode,
    required this.airingAt,
  });
}

/// A watch-history entry persisted on the device.
class AnimexHistoryEntry {
  final String key;
  final int? anilistId;
  final int malId;
  final String title;
  final String coverUrl;
  final int episode;

  /// Total episodes when known (0 = unknown, 1 = film). Anime servers
  /// never report within-episode position, so resume progress is
  /// series-based: completed episodes over this total.
  final int totalEpisodes;
  final DateTime updatedAt;

  /// The account watchlist owns progress; old local entries remain readable.
  final MediaItem? savedItem;
  int? get resumeSeconds => savedItem?.resumeSeconds;
  bool get isMovie => savedItem?.isMovie ?? totalEpisodes == 1;
  String get resumeLabel =>
      isMovie ? 'Resume movie' : 'Resume Episode $episode';

  const AnimexHistoryEntry({
    required this.key,
    this.anilistId,
    required this.malId,
    required this.title,
    required this.coverUrl,
    required this.episode,
    this.totalEpisodes = 0,
    required this.updatedAt,
    this.savedItem,
  });

  factory AnimexHistoryEntry.fromMediaItem(MediaItem item) {
    return AnimexHistoryEntry(
      key: 'animex-${item.anilistId ?? item.tmdbId}',
      anilistId: item.anilistId,
      malId: item.tmdbId,
      title: item.title,
      coverUrl: item.posterUrl,
      episode: item.currentEpisode ?? 1,
      totalEpisodes: item.isMovie ? 1 : (item.episodeCount ?? 0),
      updatedAt: item.progressUpdatedAt ?? item.addedAt,
      savedItem: item,
    );
  }

  /// Completed-episodes share, or null when there is nothing truthful
  /// to draw (unknown total, or a single-episode film).
  double? get seriesProgress {
    if (totalEpisodes <= 1 || episode <= 0) return null;
    return ((episode - 1) / totalEpisodes).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    if (anilistId != null) 'anilistId': anilistId,
    'malId': malId,
    'title': title,
    'coverUrl': coverUrl,
    'episode': episode,
    'totalEpisodes': totalEpisodes,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory AnimexHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AnimexHistoryEntry(
      key: json['key'] as String? ?? '',
      anilistId: json['anilistId'] as int?,
      malId: (json['malId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      episode: (json['episode'] as num?)?.toInt() ?? 1,
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// A user-created playlist (custom list) with an emoji avatar.
class AnimexPlaylist {
  final String id;
  final String name;
  final String emoji;
  final DateTime createdAt;
  final List<AnimexPlaylistItem> items;

  const AnimexPlaylist({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdAt,
    this.items = const [],
  });

  AnimexPlaylist copyWith({
    String? name,
    String? emoji,
    List<AnimexPlaylistItem>? items,
  }) {
    return AnimexPlaylist(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory AnimexPlaylist.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return AnimexPlaylist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? 'star',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(AnimexPlaylistItem.fromJson)
          .toList(),
    );
  }
}

class AnimexPlaylistItem {
  final int? anilistId;
  final int malId;
  final String title;
  final String coverUrl;
  final String year;
  final String format;

  const AnimexPlaylistItem({
    this.anilistId,
    required this.malId,
    required this.title,
    required this.coverUrl,
    this.year = '',
    this.format = '',
  });

  Map<String, dynamic> toJson() => {
    if (anilistId != null) 'anilistId': anilistId,
    'malId': malId,
    'title': title,
    'coverUrl': coverUrl,
    'year': year,
    'format': format,
  };

  factory AnimexPlaylistItem.fromJson(Map<String, dynamic> json) {
    return AnimexPlaylistItem(
      anilistId: json['anilistId'] as int?,
      malId: (json['malId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      year: json['year'] as String? ?? '',
      format: json['format'] as String? ?? '',
    );
  }
}

/// Builds a [MediaItem] from a watch-history entry so history and
/// continue-watching surfaces can open the watch page directly.
MediaItem mediaItemFromHistory(AnimexHistoryEntry e) {
  if (e.savedItem != null) return e.savedItem!;
  return MediaItem(
    id: '',
    tmdbId: e.malId,
    title: e.title,
    mediaType: 'tv',
    posterPath: e.coverUrl,
    year: '',
    status: '',
    isAnime: true,
    addedAt: DateTime.now(),
    source: 'jikan',
    anilistId: e.anilistId,
    currentEpisode: e.episode,
  );
}
