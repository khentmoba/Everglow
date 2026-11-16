import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_source_config.dart';
import '../../../../core/utils/firestore_stream_utils.dart';

class VideoSourceService extends ChangeNotifier {
  static final VideoSourceService _instance = VideoSourceService._internal();
  factory VideoSourceService() => _instance;
  VideoSourceService._internal();

  List<VideoSourceConfig>? _providers;
  bool _loading = false;

  bool get isLoading => _loading;

  static const Set<String> _noAdsIds = {
    'everglow-embed',
    'vidcore',
  };

  static const Set<String> _sandboxSafeIds = {'vidcore'};

  static const Set<String> _retiredIds = {
    'videasy',
    'movish',
    '111movies',
    'multiembed',
    'vidbolt',
    'vidrock',
    'vsembed',
    'vidsrc',
  };

  static const Set<String> _noSandboxIds = {'vidlink'};

  static bool _isNoAds(VideoSourceConfig p) =>
      p.sandboxSafe || _noAdsIds.contains(p.id);

  @visibleForTesting
  static List<VideoSourceConfig> currentList(List<VideoSourceConfig> list) {
    final kept = <VideoSourceConfig>[];
    for (final p in list) {
      if (_retiredIds.contains(p.id)) continue;
      if (_noSandboxIds.contains(p.id)) {
        kept.add(
          VideoSourceConfig(
            id: p.id,
            name: p.name,
            shortName: p.shortName,
            desc: p.id == 'vidlink' && p.desc.toLowerCase().contains('no ads')
                ? 'Large library, may have ads'
                : p.desc,
            movieUrl: p.movieUrl,
            tvUrl: p.tvUrl,
            isRecommended: p.isRecommended,
            sandboxSafe: false,
          ),
        );
      } else if (_sandboxSafeIds.contains(p.id) && !p.sandboxSafe) {
        kept.add(
          VideoSourceConfig(
            id: p.id,
            name: p.name,
            shortName: p.shortName,
            desc: p.desc,
            movieUrl: p.movieUrl,
            tvUrl: p.tvUrl,
            isRecommended: p.isRecommended,
            sandboxSafe: true,
          ),
        );
      } else {
        kept.add(p);
      }
    }
    return [
      ...kept.where(_isNoAds),
      ...kept.where((p) => !_isNoAds(p)),
    ];
  }

  List<VideoSourceConfig> get providers {
    if (_providers != null) return currentList(_providers!);
    _fetchFromFirestore();
    return currentList(_hardcodedDefaults);
  }

  VideoSourceConfig get defaultSource {
    final list = providers;
    for (final s in list) {
      if (s.isRecommended) return s;
    }
    return list.isNotEmpty ? list.first : _hardcodedDefaults.first;
  }

  VideoSourceConfig? byId(String id) {
    for (final s in providers) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> saveDefaultSourceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('video_source_default', id);
  }

  Future<String?> loadDefaultSourceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('video_source_default');
  }

  Future<void> refresh() async {
    _providers = null;
    await _fetchFromFirestore();
  }

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

    _providers ??= _hardcodedDefaults;
    _loading = false;
    notifyListeners();
  }

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
      desc: 'Large library, may have ads',
      movieUrl: 'https://vidlink.pro/movie/',
      tvUrl: 'https://vidlink.pro/tv/',
    ),
  ];
}
