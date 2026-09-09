/// Next-episode model for the cinema player's Up Next flow.
///
/// Pure and network-free so unit tests cover the resolver logic without
/// touching TMDB. The network layer lives in `NextEpisodeService`.
class NextEpisode {
  final int season;
  final int episode;
  final String? name;
  final String? overview;
  final String? stillPath;

  const NextEpisode({
    required this.season,
    required this.episode,
    this.name,
    this.overview,
    this.stillPath,
  });

  /// Short label used on the Next pill, e.g. "S1 E2".
  String get label => 'S$season E$episode';

  @override
  String toString() => 'NextEpisode($label, name: $name)';
}

/// Finds the episode after [currentEpisode] inside the already-fetched
/// [episodes] of [season]. Returns null when [currentEpisode] is the last
/// one (the caller should then look at the next season).
///
/// [episodes] are raw TMDB season-episode maps. Entries without an
/// `episode_number` are ignored. Never throws.
NextEpisode? nextInSeason({
  required int season,
  required int currentEpisode,
  required List<dynamic> episodes,
}) {
  final sorted = <Map<String, dynamic>>[];
  for (final raw in episodes) {
    if (raw is! Map) continue;
    final num = raw['episode_number'];
    if (num is! int) continue;
    sorted.add({
      'episode_number': num,
      'name': raw['name'],
      'overview': raw['overview'],
      'still_path': raw['still_path'],
    });
  }
  sorted.sort(
    (a, b) => (a['episode_number'] as int).compareTo(
      b['episode_number'] as int,
    ),
  );
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i]['episode_number'] == currentEpisode) {
      if (i + 1 >= sorted.length) return null;
      final next = sorted[i + 1];
      return NextEpisode(
        season: season,
        episode: next['episode_number'] as int,
        name: next['name'] as String?,
        overview: next['overview'] as String?,
        stillPath: next['still_path'] as String?,
      );
    }
  }
  // Current episode not in the list (stale data) — offer the first
  // episode after it, or the very first when nothing matches.
  for (final ep in sorted) {
    final num = ep['episode_number'] as int;
    if (num > currentEpisode) {
      return NextEpisode(
        season: season,
        episode: num,
        name: ep['name'] as String?,
        overview: ep['overview'] as String?,
        stillPath: ep['still_path'] as String?,
      );
    }
  }
  return null;
}

/// Finds the season number after [currentSeason] in [seasonNumbers].
/// Returns null when [currentSeason] is the last one. Season 0
/// (specials) is ignored unless it is the only season. Never throws.
int? nextSeasonNumber({
  required int currentSeason,
  required List<int> seasonNumbers,
}) {
  final filtered = seasonNumbers.where((n) => n > 0).toList();
  final pool = filtered.isEmpty ? seasonNumbers : filtered;
  final sorted = [...pool]..sort();
  for (final n in sorted) {
    if (n > currentSeason) return n;
  }
  return null;
}

/// Picks the first episode of a freshly fetched season (used when
/// crossing into a new season). Returns null for an empty list.
NextEpisode? firstInSeason({
  required int season,
  required List<dynamic> episodes,
}) {
  final sorted = <Map<String, dynamic>>[];
  for (final raw in episodes) {
    if (raw is! Map) continue;
    final num = raw['episode_number'];
    if (num is! int) continue;
    sorted.add({
      'episode_number': num,
      'name': raw['name'],
      'overview': raw['overview'],
      'still_path': raw['still_path'],
    });
  }
  if (sorted.isEmpty) return null;
  sorted.sort(
    (a, b) => (a['episode_number'] as int).compareTo(
      b['episode_number'] as int,
    ),
  );
  final first = sorted.first;
  return NextEpisode(
    season: season,
    episode: first['episode_number'] as int,
    name: first['name'] as String?,
    overview: first['overview'] as String?,
    stillPath: first['still_path'] as String?,
  );
}
