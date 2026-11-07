import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../agent/agent_mode.dart';
import '../../utils/logger.dart';
import 'offline_media_item.dart';
import 'offline_media_storage.dart';

/// Central management service for downloaded offline movies, TV show episodes,
/// anime episodes, and manga chapters in Everglow.
class OfflineMediaService extends ChangeNotifier {
  static final OfflineMediaService instance = OfflineMediaService._();

  OfflineMediaService._({OfflineMediaStorage? storage})
    : _storage = storage ?? OfflineMediaStorage.instance {
    _init();
  }

  factory OfflineMediaService({OfflineMediaStorage? storage}) {
    if (storage != null) {
      return OfflineMediaService._(storage: storage);
    }
    return instance;
  }

  static const String _prefsKey = 'everglow_offline_media_items_v1';
  final OfflineMediaStorage _storage;

  final Map<String, OfflineMediaItem> _items = {};
  bool _initialized = false;
  final Map<String, Timer> _activeDownloadSimulators = {};

  bool get isInitialized => _initialized;

  List<OfflineMediaItem> get allItems => _items.values.toList()
    ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

  List<OfflineMediaItem> get cinemaItems =>
      allItems.where((i) => i.isCinema).toList();

  List<OfflineMediaItem> get animeItems =>
      allItems.where((i) => i.isAnime).toList();

  List<OfflineMediaItem> get mangaItems =>
      allItems.where((i) => i.isManga).toList();

  int get totalStorageBytes {
    return _items.values.fold(0, (sum, item) {
      final b = item.totalBytes > 0 ? item.totalBytes : item.downloadedBytes;
      return sum + b;
    });
  }

  String get formattedTotalStorage {
    final bytes = totalStorageBytes;
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> init() => _init();

  Future<void> _init() async {
    if (_initialized) return;
    await _storage.init();
    await _loadFromStorage();
    if (_items.isEmpty &&
        (AgentMode.isActive.value || AgentMode.useDemoData.value)) {
      _seedDemoData();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final entry in list) {
          if (entry is Map<String, dynamic>) {
            final item = OfflineMediaItem.fromJson(entry);
            _items[item.id] = item;
          }
        }
      }
    } catch (e) {
      Logger.e('OfflineMediaService: could not load stored registry', error: e);
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.values.map((e) => e.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (e) {
      Logger.e('OfflineMediaService: could not persist registry', error: e);
    }
  }

  /// Seeds safe mock offline media fixtures for agent mode and offline testing.
  void _seedDemoData() {
    for (final item in _demoItems) {
      _items[item.id] = item;
    }
    unawaited(_saveToStorage());
  }

  bool isDownloaded(String id) {
    final item = _items[id];
    return item != null && item.status == OfflineDownloadStatus.completed;
  }

  bool isDownloading(String id) {
    final item = _items[id];
    return item != null && item.status == OfflineDownloadStatus.downloading;
  }

  OfflineMediaItem? getItem(String id) => _items[id];

  List<OfflineMediaItem> getEpisodesForSeries(String mediaId, {int? season}) {
    return _items.values.where((item) {
      if (item.mediaId != mediaId || !item.isEpisode) return false;
      if (season != null && item.season != season) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final sComp = (a.season ?? 0).compareTo(b.season ?? 0);
        if (sComp != 0) return sComp;
        return (a.episode ?? 0).compareTo(b.episode ?? 0);
      });
  }

  List<OfflineMediaItem> getChaptersForManga(String slug) {
    return _items.values.where((item) {
      return item.isManga && item.mediaId == slug;
    }).toList()
      ..sort((a, b) => (a.chapterId ?? '').compareTo(b.chapterId ?? ''));
  }

  /// Starts downloading a movie, TV show episode, or anime episode.
  Future<void> startDownloadMedia({
    required String id,
    required OfflineMediaType type,
    required String mediaId,
    required String title,
    String subtitle = '',
    int? season,
    int? episode,
    String coverUrl = '',
    String? sourceUrl,
    int? durationSeconds,
    int estimatedBytes = 350 * 1024 * 1024,
    Uint8List? directBytes,
  }) async {
    final existing = _items[id];
    if (existing != null &&
        existing.status == OfflineDownloadStatus.completed) {
      return;
    }

    final isCompletedDirect = directBytes != null;
    final initial = OfflineMediaItem(
      id: id,
      type: type,
      mediaId: mediaId,
      title: title,
      subtitle: subtitle,
      season: season,
      episode: episode,
      coverUrl: coverUrl,
      sourceUrl: sourceUrl,
      status: isCompletedDirect
          ? OfflineDownloadStatus.completed
          : OfflineDownloadStatus.downloading,
      progress: isCompletedDirect ? 1.0 : 0.05,
      totalBytes:
          isCompletedDirect ? directBytes.lengthInBytes : estimatedBytes,
      downloadedBytes: isCompletedDirect
          ? directBytes.lengthInBytes
          : (estimatedBytes * 0.05).round(),
      downloadedAt: DateTime.now(),
      durationSeconds: durationSeconds,
      blobKey: id,
    );

    _items[id] = initial;
    notifyListeners();
    await _saveToStorage();

    if (directBytes != null) {
      await _storage.saveMediaBlob(id, directBytes);
      return;
    }

    // Simulate progressive download chunks if not given directly
    _simulateProgress(id, estimatedBytes);
  }

  /// Starts downloading a manga chapter with its pages.
  Future<void> startDownloadMangaChapter({
    required String slug,
    required String mangaTitle,
    required String coverUrl,
    required String chapterId,
    required String chapterTitle,
    required List<String> pageUrls,
    List<Uint8List>? pageBytesList,
  }) async {
    final id = 'manga_${slug}_ch_$chapterId';
    final existing = _items[id];
    if (existing != null &&
        existing.status == OfflineDownloadStatus.completed) {
      return;
    }

    final estimatedBytes = pageUrls.length * 750 * 1024;
    final initial = OfflineMediaItem(
      id: id,
      type: OfflineMediaType.manga,
      mediaId: slug,
      title: mangaTitle,
      subtitle: chapterTitle,
      chapterId: chapterId,
      coverUrl: coverUrl,
      status: OfflineDownloadStatus.downloading,
      progress: 0.1,
      totalBytes: estimatedBytes,
      downloadedBytes: (estimatedBytes * 0.1).round(),
      downloadedAt: DateTime.now(),
      pageUrls: pageUrls,
      blobKey: id,
    );

    _items[id] = initial;
    notifyListeners();
    await _saveToStorage();

    if (pageBytesList != null && pageBytesList.isNotEmpty) {
      var saved = 0;
      for (var i = 0; i < pageBytesList.length; i++) {
        final pageKey = '${id}_p_${i + 1}';
        await _storage.saveMangaPage(pageKey, pageBytesList[i]);
        saved++;
        final progress = (saved / pageBytesList.length).clamp(0.0, 1.0);
        _items[id] = _items[id]!.copyWith(
          progress: progress,
          downloadedBytes: (estimatedBytes * progress).round(),
        );
        notifyListeners();
      }
      _items[id] = _items[id]!.copyWith(
        status: OfflineDownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: estimatedBytes,
      );
      notifyListeners();
      await _saveToStorage();
      return;
    }

    _simulateProgress(id, estimatedBytes);
  }

  void _simulateProgress(String id, int totalBytes) {
    _activeDownloadSimulators[id]?.cancel();
    var step = 1;
    const totalSteps = 10;
    _activeDownloadSimulators[id] = Timer.periodic(
      const Duration(milliseconds: 300),
      (timer) async {
        final current = _items[id];
        if (current == null ||
            current.status == OfflineDownloadStatus.paused) {
          timer.cancel();
          _activeDownloadSimulators.remove(id);
          return;
        }

        step++;
        final progress = (step / totalSteps).clamp(0.0, 1.0);
        final downloaded = (totalBytes * progress).round();

        if (step >= totalSteps) {
          timer.cancel();
          _activeDownloadSimulators.remove(id);
          _items[id] = current.copyWith(
            status: OfflineDownloadStatus.completed,
            progress: 1.0,
            downloadedBytes: totalBytes,
          );
        } else {
          _items[id] = current.copyWith(
            progress: progress,
            downloadedBytes: downloaded,
          );
        }
        notifyListeners();
        await _saveToStorage();
      },
    );
  }

  Future<void> pauseDownload(String id) async {
    final item = _items[id];
    if (item == null) return;
    _activeDownloadSimulators[id]?.cancel();
    _activeDownloadSimulators.remove(id);
    _items[id] = item.copyWith(status: OfflineDownloadStatus.paused);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> resumeDownload(String id) async {
    final item = _items[id];
    if (item == null) return;
    _items[id] = item.copyWith(status: OfflineDownloadStatus.downloading);
    notifyListeners();
    await _saveToStorage();
    _simulateProgress(id, item.totalBytes > 0 ? item.totalBytes : 350 * 1024 * 1024);
  }

  Future<void> deleteDownload(String id) async {
    _activeDownloadSimulators[id]?.cancel();
    _activeDownloadSimulators.remove(id);
    final item = _items.remove(id);
    if (item != null) {
      if (item.blobKey != null) {
        await _storage.deleteBlob(item.blobKey!, isManga: item.isManga);
      }
      if (item.isManga) {
        for (var i = 1; i <= item.pageUrls.length; i++) {
          await _storage.deleteBlob('${id}_p_$i', isManga: true);
        }
      }
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> clearAll({OfflineMediaType? type}) async {
    for (final timer in _activeDownloadSimulators.values) {
      timer.cancel();
    }
    _activeDownloadSimulators.clear();

    if (type == null) {
      _items.clear();
      await _storage.clearAll();
    } else {
      final toRemove = _items.values.where((i) => i.type == type).map((i) => i.id).toList();
      for (final id in toRemove) {
        final item = _items.remove(id);
        if (item?.blobKey != null) {
          await _storage.deleteBlob(item!.blobKey!, isManga: item.isManga);
        }
      }
    }
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> updatePlaybackPosition(String id, int positionSeconds) async {
    final item = _items[id];
    if (item == null) return;
    _items[id] = item.copyWith(lastPositionSeconds: positionSeconds);
    await _saveToStorage();
  }

  Future<String?> getPlayableUrl(OfflineMediaItem item) async {
    if (item.blobKey != null) {
      final url = await _storage.getBlobUrl(item.blobKey!, isManga: item.isManga);
      if (url != null) return url;
    }
    // Return sample playable demo video or sourceUrl if blob not populated
    return item.sourceUrl ??
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
  }

  Future<String?> getMangaPageUrl(String itemId, int pageNumber) async {
    final pageKey = '${itemId}_p_$pageNumber';
    final url = await _storage.getBlobUrl(pageKey, isManga: true);
    if (url != null) return url;
    final item = _items[itemId];
    if (item != null &&
        pageNumber > 0 &&
        pageNumber <= item.pageUrls.length) {
      return item.pageUrls[pageNumber - 1];
    }
    return null;
  }

  static final List<OfflineMediaItem> _demoItems = [
    OfflineMediaItem(
      id: 'cinema_movie_157336',
      type: OfflineMediaType.movie,
      mediaId: '157336',
      title: 'Interstellar',
      subtitle: 'Movie • 2014',
      coverUrl:
          'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
      sourceUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      status: OfflineDownloadStatus.completed,
      progress: 1.0,
      totalBytes: 1520000000,
      downloadedBytes: 1520000000,
      downloadedAt: DateTime.now().subtract(const Duration(hours: 3)),
      durationSeconds: 10140,
      lastPositionSeconds: 1250,
      blobKey: 'cinema_movie_157336',
    ),
    OfflineMediaItem(
      id: 'cinema_tv_66732_s1_e1',
      type: OfflineMediaType.tv,
      mediaId: '66732',
      title: 'Stranger Things',
      subtitle: 'S1 E1 • Chapter One: The Vanishing of Will Byers',
      season: 1,
      episode: 1,
      coverUrl:
          'https://image.tmdb.org/t/p/w500/49WJfeN0moxb9IPfGn8AIqMGskD.jpg',
      sourceUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      status: OfflineDownloadStatus.completed,
      progress: 1.0,
      totalBytes: 740000000,
      downloadedBytes: 740000000,
      downloadedAt: DateTime.now().subtract(const Duration(hours: 2)),
      durationSeconds: 2940,
      lastPositionSeconds: 420,
      blobKey: 'cinema_tv_66732_s1_e1',
    ),
    OfflineMediaItem(
      id: 'cinema_tv_66732_s1_e2',
      type: OfflineMediaType.tv,
      mediaId: '66732',
      title: 'Stranger Things',
      subtitle: 'S1 E2 • Chapter Two: The Weirdo on Maple Street',
      season: 1,
      episode: 2,
      coverUrl:
          'https://image.tmdb.org/t/p/w500/49WJfeN0moxb9IPfGn8AIqMGskD.jpg',
      sourceUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      status: OfflineDownloadStatus.completed,
      progress: 1.0,
      totalBytes: 710000000,
      downloadedBytes: 710000000,
      downloadedAt: DateTime.now().subtract(const Duration(hours: 2)),
      durationSeconds: 3300,
      lastPositionSeconds: 0,
      blobKey: 'cinema_tv_66732_s1_e2',
    ),
    OfflineMediaItem(
      id: 'cinema_tv_66732_s2_e1',
      type: OfflineMediaType.tv,
      mediaId: '66732',
      title: 'Stranger Things',
      subtitle: 'S2 E1 • Chapter One: MADMAX',
      season: 2,
      episode: 1,
      coverUrl:
          'https://image.tmdb.org/t/p/w500/49WJfeN0moxb9IPfGn8AIqMGskD.jpg',
      sourceUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      status: OfflineDownloadStatus.completed,
      progress: 1.0,
      totalBytes: 780000000,
      downloadedBytes: 780000000,
      downloadedAt: DateTime.now().subtract(const Duration(hours: 1)),
      durationSeconds: 2880,
      lastPositionSeconds: 0,
      blobKey: 'cinema_tv_66732_s2_e1',
    ),
    OfflineMediaItem(
      id: 'anime_154587_s1_e1',
      type: OfflineMediaType.anime,
      mediaId: '154587',
      title: 'Frieren: Beyond Journey\'s End',
      subtitle: 'Episode 1 • The Journey\'s End',
      season: 1,
      episode: 1,
      coverUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-n1HJZ2s7vGgA.jpg',
      sourceUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
      status: OfflineDownloadStatus.completed,
      progress: 1.0,
      totalBytes: 420000000,
      downloadedBytes: 420000000,
      downloadedAt: DateTime.now().subtract(const Duration(minutes: 90)),
      durationSeconds: 1440,
      lastPositionSeconds: 610,
      blobKey: 'anime_154587_s1_e1',
    ),
    OfflineMediaItem(
      id: 'anime_154587_s1_e2',
      type: OfflineMediaType.anime,
      mediaId: '154587',
      title: 'Frieren: Beyond Journey\'s End',
      subtitle: 'Episode 2 • It Didn\'t Have to Be Magic...',
      season: 1,
      episode: 2,
      coverUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-n1HJZ2s7vGgA.jpg',
      sourceUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
      status: OfflineDownloadStatus.completed,
      progress: 1.0,
      totalBytes: 415000000,
      downloadedBytes: 415000000,
      downloadedAt: DateTime.now().subtract(const Duration(minutes: 80)),
      durationSeconds: 1440,
      lastPositionSeconds: 0,
      blobKey: 'anime_154587_s1_e2',
    ),
    OfflineMediaItem(
      id: 'anime_154587_s1_e3',
      type: OfflineMediaType.anime,
      mediaId: '154587',
      title: 'Frieren: Beyond Journey\'s End',
      subtitle: 'Episode 3 • Killing Magic',
      season: 1,
      episode: 3,
      coverUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-n1HJZ2s7vGgA.jpg',
      sourceUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      status: OfflineDownloadStatus.completed,
      progress: 1.0,
      totalBytes: 430000000,
      downloadedBytes: 430000000,
      downloadedAt: DateTime.now().subtract(const Duration(minutes: 70)),
      durationSeconds: 1440,
      lastPositionSeconds: 0,
      blobKey: 'anime_154587_s1_e3',
    ),
    OfflineMediaItem(
      id: 'manga_solo-leveling_ch_1',
      type: OfflineMediaType.manga,
      mediaId: 'solo-leveling',
      title: 'Solo Leveling',
      subtitle: 'Chapter 1: I\'m Used to It',
      chapterId: '1',
      coverUrl:
          'https://uploads.mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/37aeaa0a-8bf7-42f5-b28e-f5139031c03a.jpg',
      status: OfflineDownloadStatus.completed,
      progress: 1.0,
      totalBytes: 24000000,
      downloadedBytes: 24000000,
      downloadedAt: DateTime.now().subtract(const Duration(minutes: 50)),
      pageUrls: [
        'assets/images/demo/poster-1.jpg',
        'assets/images/demo/poster-2.jpg',
        'assets/images/demo/poster-3.jpg',
      ],
      blobKey: 'manga_solo-leveling_ch_1',
    ),
    OfflineMediaItem(
      id: 'manga_solo-leveling_ch_2',
      type: OfflineMediaType.manga,
      mediaId: 'solo-leveling',
      title: 'Solo Leveling',
      subtitle: 'Chapter 2: The Double Dungeon',
      chapterId: '2',
      coverUrl:
          'https://uploads.mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/37aeaa0a-8bf7-42f5-b28e-f5139031c03a.jpg',
      status: OfflineDownloadStatus.completed,
      progress: 1.0,
      totalBytes: 28000000,
      downloadedBytes: 28000000,
      downloadedAt: DateTime.now().subtract(const Duration(minutes: 40)),
      pageUrls: [
        'assets/images/demo/poster-1.jpg',
        'assets/images/demo/poster-2.jpg',
        'assets/images/demo/poster-3.jpg',
      ],
      blobKey: 'manga_solo-leveling_ch_2',
    ),
  ];
}
