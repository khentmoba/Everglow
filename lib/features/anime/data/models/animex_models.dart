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
  final int durationSeconds;
  final int episodeMinutes;
  final DateTime updatedAt;

  const AnimexHistoryEntry({
    required this.key,
    this.anilistId,
    required this.malId,
    required this.title,
    required this.coverUrl,
    required this.episode,
    this.durationSeconds = 0,
    this.episodeMinutes = 24,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    if (anilistId != null) 'anilistId': anilistId,
    'malId': malId,
    'title': title,
    'coverUrl': coverUrl,
    'episode': episode,
    'durationSeconds': durationSeconds,
    'episodeMinutes': episodeMinutes,
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
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      episodeMinutes: (json['episodeMinutes'] as num?)?.toInt() ?? 24,
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
