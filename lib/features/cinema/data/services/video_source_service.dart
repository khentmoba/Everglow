import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_source_config.dart';
import '../../../../core/utils/firestore_stream_utils.dart';

/// Singleton service that provides the ordered list of video embed sources.
///
/// Sources are loaded from a Firestore document (`config/video_sources`)
/// on first access. A hardcoded default list serves as fallback when
/// Firestore is unreachable or the document doesn't exist.
///
/// The resolved list is cached in memory for the session. Callers should
/// re-fetch explicitly (via [refresh]) when they want to pick up remote
/// changes without a restart.
///
/// Extends [ChangeNotifier] so UI consumers can listen for provider-list
/// updates when the Firestore fetch completes asynchronously.
class VideoSourceService extends ChangeNotifier {
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
  static const Set<String> _noAdsIds = {
    'everglow-embed',
    'vidbolt',
    'vidcore',
    'vidlink',
  };

  /// Sources we stopped offering after the 2026-10-04 live audit, with
  /// the upstream fact that killed each one:
  ///
  /// - `videasy` — `player.videasy.net` 301s to `player.videasy.to`,
  ///   whose certificate does not chain to a trusted root, so every
  ///   browser refuses it.
  /// - `movish` — the `/moviebox-embed/` embed paths return 404.
  /// - `111movies` — the domain no longer resolves in DNS.
  /// - `multiembed` — redirects to a Cloudflare Turnstile CAPTCHA wall.
  ///
  /// The Firestore config still carries these entries, so the filter
  /// belongs where the list is resolved rather than in the fallback list
  /// alone; otherwise dead servers keep coming back the moment a remote
  /// config is present.
  static const Set<String> _retiredIds = {
    'videasy',
    'movish',
    '111movies',
    'multiembed',
  };

  /// Providers that stream fine but refuse to run inside a sandboxed
  /// iframe — VidBolt answers "Playback Disabled" and VidLink answers
  /// "Please Disable Sandbox", so `sandboxSafe: true` was exactly what
  /// broke them. The remote config still carries that flag.
  static const Set<String> _noSandboxIds = {'vidbolt', 'vidlink'};

  static bool _isNoAds(VideoSourceConfig p) =>
      p.sandboxSafe || _noAdsIds.contains(p.id);

  /// The list we actually offer: retired sources removed, sandbox flags
  /// corrected, no-ads providers grouped first.
  ///
  /// Applies to the Firestore list and the hardcoded fallback alike so a
  /// stale remote entry can never reintroduce a dead or unplayable server.
  ///
  /// Public only so the normalization itself can be tested against a
  /// stale remote list; production code goes through [providers].
  @visibleForTesting
  static List<VideoSourceConfig> currentList(List<VideoSourceConfig> list) {
    final kept = <VideoSourceConfig>[];
    for (final p in list) {
      if (_retiredIds.contains(p.id)) continue;
      kept.add(
        _noSandboxIds.contains(p.id) && p.sandboxSafe
            ? VideoSourceConfig(
                id: p.id,
                name: p.name,
                shortName: p.shortName,
                desc: p.desc,
                movieUrl: p.movieUrl,
                tvUrl: p.tvUrl,
                isRecommended: p.isRecommended,
                sandboxSafe: false,
              )
            : p,
      );
    }
    return [
      ...kept.where(_isNoAds),
      ...kept.where((p) => !_isNoAds(p)),
    ];
  }

  List<VideoSourceConfig> get providers {
    if (_providers != null) return currentList(_providers!);
    // Start a background fetch; return fallback for now.
    _fetchFromFirestore();
    return currentList(_hardcodedDefaults);
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
    // _fetchFromFirestore already calls notifyListeners on completion.
  }

  // ---------------------------------------------------------------------------
  // Firestore fetch
  // ---------------------------------------------------------------------------
  Future<void> _fetchFromFirestore() async {
    if (_loading) return;
    _loading = true;

    try {
      final doc = await withGetTimeout(
        FirebaseFirestore.instance
            .collection('config')
            .doc('video_sources')
            .get(),
        label: 'video sources config',
      );

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final sourcesRaw = data['sources'] as List<dynamic>?;
        if (sourcesRaw != null && sourcesRaw.isNotEmpty) {
          final loaded = sourcesRaw
              .map(
                (e) =>
                    VideoSourceConfig.fromFirestore(e as Map<String, dynamic>),
              )
              .toList();
          _providers = currentList(loaded);
          _loading = false;
          debugPrint(
            '[VideoSourceService] Loaded ${_providers!.length} sources from Firestore (retired removed, no-ads first)',
          );
          notifyListeners();
          return;
        }
      }
      debugPrint(
        '[VideoSourceService] Firestore doc missing or empty — using hardcoded defaults',
      );
    } catch (e) {
      debugPrint('[VideoSourceService] Firestore fetch failed: $e');
    }

    // Fallback: use the hardcoded list.
    _providers ??= _hardcodedDefaults;
    _loading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Hardcoded fallback defaults.
  //
  // A live audit on 2026-10-04 removed four servers (see [_retiredIds]) and
  // dropped the sandbox flag on VidBolt and VidLink (see [_noSandboxIds]).
  // Everything left here was verified to stream a real movie and TV episode
  // inside the app's iframe; re-verify before adding a new entry.
  // ---------------------------------------------------------------------------
  static final List<VideoSourceConfig> _hardcodedDefaults = [
    const VideoSourceConfig(
      id: 'everglow-embed',
      name: 'Everglow',
      shortName: 'Everglow',
      desc: 'No ads — Everglow player',
      movieUrl: 'https://everglow-1c6db.web.app/embed.html',
      tvUrl: 'https://everglow-1c6db.web.app/embed.html',
      isRecommended: true,
      sandboxSafe: true,
    ),
    const VideoSourceConfig(
      id: 'vidbolt',
      name: 'VidBolt',
      shortName: 'VidBolt',
      desc: 'No ads, high quality, multi-server',
      movieUrl: 'https://vidbolt.xyz/movie/',
      tvUrl: 'https://vidbolt.xyz/tv/',
      isRecommended: true,
    ),
    const VideoSourceConfig(
      id: 'vidcore',
      name: 'VidCore',
      shortName: 'VidCore',
      desc: 'Ad-free — sandbox safe',
      movieUrl: 'https://vidcore.org/embed/movie/',
      tvUrl: 'https://vidcore.org/embed/tv/',
      isRecommended: true,
      sandboxSafe: true,
    ),
    const VideoSourceConfig(
      id: 'vidlink',
      name: 'VidLink',
      shortName: 'VidLink',
      desc: 'Large library, no ads',
      movieUrl: 'https://vidlink.pro/movie/',
      tvUrl: 'https://vidlink.pro/tv/',
    ),
    const VideoSourceConfig(
      id: 'vsembed',
      name: 'VsEmbed',
      shortName: 'VsEmbed',
      desc: 'VidSrc network mirror',
      movieUrl: 'https://vsembed.ru/embed/movie/',
      tvUrl: 'https://vsembed.ru/embed/',
    ),
    const VideoSourceConfig(
      id: 'vidrock',
      name: 'VidRock',
      shortName: 'VidRock',
      desc: 'Has Adcash — last resort',
      movieUrl: 'https://vidrock.ru/movie/',
      tvUrl: 'https://vidrock.ru/tv/',
    ),
    const VideoSourceConfig(
      id: 'vidsrc',
      name: 'VidSrc',
      shortName: 'VidSrc',
      desc: 'Last resort, has trackers',
      movieUrl: 'https://vidsrc.to/embed/movie/',
      tvUrl: 'https://vidsrc.to/embed/tv/',
    ),
  ];
}
