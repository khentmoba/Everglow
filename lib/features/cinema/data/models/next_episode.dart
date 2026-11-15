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

  String get label => 'S$season E$episode';

  @override
  String toString() => 'NextEpisode($label, name: $name)';
}

bool _hasAired(Map<String, dynamic> ep, DateTime today) {
  final airDate = ep['air_date'];
  if (airDate is! String || airDate.isEmpty) return true;
  final parsed = DateTime.tryParse(airDate);
  if (parsed == null) return true;
  return !DateTime(parsed.year, parsed.month, parsed.day).isAfter(today);
}

NextEpisode? nextInSeason({
  required int season,
  required int currentEpisode,
  required List<dynamic> episodes,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
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
      'air_date': raw['air_date'],
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
      if (!_hasAired(next, today)) return null;
      return NextEpisode(
        season: season,
        episode: next['episode_number'] as int,
        name: next['name'] as String?,
        overview: next['overview'] as String?,
        stillPath: next['still_path'] as String?,
      );
    }
  }
  for (final ep in sorted) {
    final num = ep['episode_number'] as int;
    if (num > currentEpisode && _hasAired(ep, today)) {
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

NextEpisode? firstInSeason({
  required int season,
  required List<dynamic> episodes,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
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
      'air_date': raw['air_date'],
    });
  }
  if (sorted.isEmpty) return null;
  sorted.sort(
    (a, b) => (a['episode_number'] as int).compareTo(
      b['episode_number'] as int,
    ),
  );
  final first = sorted.first;
  if (!_hasAired(first, today)) return null;
  return NextEpisode(
    season: season,
    episode: first['episode_number'] as int,
    name: first['name'] as String?,
    overview: first['overview'] as String?,
    stillPath: first['still_path'] as String?,
  );
}
