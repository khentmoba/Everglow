import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/features/cinema/data/models/video_source_config.dart';

/// Singleton service that provides the ordered list of video embed sources.
///
/// Sources are loaded from a Firestore document (`config/video_sources`)
/// on first access. A hardcoded default list serves as fallback when
/// Firestore is unreachable or the document doesn't exist.
///
/// The resolved list is cached in memory for the session. Callers should
/// re-fetch explicitly (via [refresh]) when they want to pick up remote
/// changes without a restart.
class VideoSourceService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  static final VideoSourceService _instance = VideoSourceService._internal();
  factory VideoSourceService() => _instance;
  VideoSourceService._internal();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  List<VideoSourceConfig>? _providers;
  bool _loading = false;

  /// Whether the service is currently fetching from Firestore.
  bool get isLoading => _loading;

  /// Ordered list of all available video sources.
  ///
  /// Returns the cached list immediately if already loaded; otherwise
  /// kicks off a Firestore fetch and falls back to the hardcoded list
  /// while waiting.
  List<VideoSourceConfig> get providers {
    if (_providers != null) return _providers!;
    // Start a background fetch; return fallback for now.
    _fetchFromFirestore();
    return _hardcodedDefaults;
  }

  /// The first recommended source, or the first source overall.
  VideoSourceConfig get defaultSource {
    final list = providers;
    // Prefer the first recommended entry.
    for (final s in list) {
      if (s.isRecommended) return s;
    }
    return list.isNotEmpty ? list.first : _hardcodedDefaults.first;
  }

  /// Look up a source by [id]. Returns `null` when not found.
  VideoSourceConfig? byId(String id) {
    for (final s in providers) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Persist the user's preferred source id to SharedPreferences.
  Future<void> saveDefaultSourceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('video_source_default', id);
  }

  /// Read the user's preferred source id from SharedPreferences.
  /// Returns `null` when never set.
  Future<String?> loadDefaultSourceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('video_source_default');
  }

  /// Force a re-fetch from Firestore. Useful after a settings change
  /// or when the app detects a stale config.
  Future<void> refresh() async {
    _providers = null;
    await _fetchFromFirestore();
  }

  // ---------------------------------------------------------------------------
  // Firestore fetch
  // ---------------------------------------------------------------------------
  Future<void> _fetchFromFirestore() async {
    if (_loading) return;
    _loading = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('video_sources')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final sourcesRaw = data['sources'] as List<dynamic>?;
        if (sourcesRaw != null && sourcesRaw.isNotEmpty) {
          _providers = sourcesRaw
              .map((e) => VideoSourceConfig.fromFirestore(
                    e as Map<String, dynamic>,
                  ))
              .toList();
          _loading = false;
          return;
        }
      }
    } catch (_) {
      // Firestore unavailable — keep the fallback below.
    }

    // Fallback: use the hardcoded list.
    _providers ??= _hardcodedDefaults;
    _loading = false;
  }

  // ---------------------------------------------------------------------------
  // Hardcoded fallback defaults (mirrors the old 9-provider list)
  // ---------------------------------------------------------------------------
  static final List<VideoSourceConfig> _hardcodedDefaults = [
    VideoSourceConfig(
      id: 'vidfast',
      name: 'VidFast',
      shortName: 'VidFast',
      desc: 'Fast, multiple CDN domains',
      movieUrl: 'https://vidfast.pro/movie/',
      tvUrl: 'https://vidfast.pro/tv/',
      isRecommended: true,
    ),
    VideoSourceConfig(
      id: 'vidlink',
      name: 'VidLink',
      shortName: 'VidLink',
      desc: 'Solid, actively maintained',
      movieUrl: 'https://vidlink.pro/movie/',
      tvUrl: 'https://vidlink.pro/tv/',
      isRecommended: true,
    ),
    VideoSourceConfig(
      id: 'multiembed',
      name: 'MultiEmbed',
      shortName: 'MultiEmbed',
      desc: 'Multi-source fallback',
      movieUrl: 'https://multiembed.mov/?video_id=',
      tvUrl: 'https://multiembed.mov/?video_id=',
    ),
    VideoSourceConfig(
      id: '2embed.cc',
      name: '2Embed',
      shortName: '2Embed',
      desc: 'Direct TMDB-based source',
      movieUrl: 'https://www.2embed.cc/embed/',
      tvUrl: 'https://www.2embed.cc/embedtv/',
    ),
    VideoSourceConfig(
      id: 'videasy',
      name: 'Videasy',
      shortName: 'Videasy',
      desc: 'Clean, modern player',
      movieUrl: 'https://player.videasy.net/movie/',
      tvUrl: 'https://player.videasy.net/tv/',
      isRecommended: true,
    ),
    VideoSourceConfig(
      id: 'vsembed',
      name: 'VsEmbed',
      shortName: 'VsEmbed',
      desc: 'VidSrc network mirror',
      movieUrl: 'https://vsembed.ru/embed/movie/',
      tvUrl: 'https://vsembed.ru/embed/',
    ),
    VideoSourceConfig(
      id: 'vidrock',
      name: 'VidRock',
      shortName: 'VidRock',
      desc: 'Reliable VidSrc mirror',
      movieUrl: 'https://vidrock.ru/movie/',
      tvUrl: 'https://vidrock.ru/tv/',
    ),
    VideoSourceConfig(
      id: '111movies',
      name: '111Movies',
      shortName: '111Movies',
      desc: 'Alternative embed source',
      movieUrl: 'https://111movies.com/movie/',
      tvUrl: 'https://111movies.com/tv/',
    ),
    VideoSourceConfig(
      id: 'vidsrc',
      name: 'VidSrc',
      shortName: 'VidSrc',
      desc: 'Last resort, ad-heavy',
      movieUrl: 'https://vidsrc.to/embed/movie/',
      tvUrl: 'https://vidsrc.to/embed/tv/',
    ),
  ];
}
