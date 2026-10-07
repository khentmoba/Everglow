/// Fictional catalogue records for offline Agent Mode, never real couple data.
const _titles = [
  'Moonlit Cinema',
  'The Lantern Trail',
  'Letters from Tomorrow',
  'Summer at Sea',
  'The Midnight Library',
  'A Little Adventure',
  'Cloud Nine',
  'Starlight Station',
];

List<Map<String, dynamic>> get _records => [
  for (var i = 0; i < _titles.length; i++)
    {
      'id': 900000 + i,
      'media_type': i < 4 ? 'movie' : 'tv',
      'title': _titles[i],
      'name': _titles[i],
      'overview':
          'A fictional story about friendship and finding your way home. '
          'This title is demo data for testing the Cinema drawer.',
      'release_date': '2025-06-01',
      'first_air_date': '2025-06-01',
      'original_language': 'en',
      'genre_ids': [18, 12],
      'genres': [
        {'id': 18, 'name': 'Drama'},
        {'id': 12, 'name': 'Adventure'},
      ],
      'vote_average': 8.2,
      'vote_count': 120,
      'popularity': 30.0,
      'runtime': 104,
      'episode_run_time': [24],
      'number_of_seasons': 1,
      'number_of_episodes': 3,
      'seasons': [
        {'season_number': 1, 'episode_count': 3, 'name': 'Season 1'},
      ],
      'spoken_languages': [
        {'english_name': 'English'},
      ],
    },
];

Map<String, dynamic>? agentTmdbResponse(Uri url) {
  final path = url.pathSegments
      .skipWhile((s) => s != 'proxyTmdb')
      .skip(1)
      .toList();
  if (path.isEmpty) return null;
  if (path.first == 'genre') {
    return {
      'genres': [
        {'id': 18, 'name': 'Drama'},
        {'id': 12, 'name': 'Adventure'},
      ],
    };
  }
  if (path.length > 1 &&
      int.tryParse(path[1]) != null &&
      (path.first == 'movie' || path.first == 'tv')) {
    final matches = _records.where(
      (r) => r['id'] == int.parse(path[1]) && r['media_type'] == path.first,
    );
    if (matches.isEmpty) return null;
    if (path.length == 2) return matches.first;
    if (path[2] == 'credits') return {'cast': []};
    if (path[2] == 'season') {
      return {
        'episodes': [
          for (var i = 1; i <= 3; i++)
            {
              'id': i,
              'episode_number': i,
              'season_number': 1,
              'name': 'Demo Episode $i',
              'overview': 'A fictional episode for local testing.',
              'runtime': 24,
              'air_date': '2025-06-01',
            },
        ],
      };
    }
    if (path[2] == 'similar') return {'results': _records};
    return {'results': []}; // No trailers or third-party reviews in demo mode.
  }
  final type = path.contains('movie')
      ? 'movie'
      : path.contains('tv')
      ? 'tv'
      : null;
  final query = (url.queryParameters['query'] ?? '').toLowerCase();
  final page = int.tryParse(url.queryParameters['page'] ?? '1') ?? 1;
  final records = _records
      .where(
        (r) =>
            (type == null || r['media_type'] == type) &&
            (r['title'] as String).toLowerCase().contains(query),
      )
      .toList();
  return {
    'page': page,
    'total_pages': 1,
    'total_results': records.length,
    'results': page == 1 ? records : [],
  };
}
