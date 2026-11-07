import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../agent/agent_mode.dart';
import '../../utils/logger.dart';
import '../../../features/manga/data/services/katana_service.dart';
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

  bool get isInitialized => _initialized;

  static String mangaChapterId(String slug, String chapterId) =>
      'manga_${slug}_ch_$chapterId';

  static String animeEpisodeId(dynamic animeId, int episode, {int season = 1}) =>
      'anime_${animeId}_s${season}_e$episode';

  static String cinemaEpisodeId(int tmdbId, int season, int episode) =>
      'cinema_tv_${tmdbId}_s${season}_e$episode';

  static String cinemaMovieId(int tmdbId) => 'cinema_movie_$tmdbId';

  List<OfflineMediaItem> get allItems => _items.values
      .where((i) => i.isCompleted || i.isDownloading)
      .toList()
    ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

  List<OfflineMediaItem> get cinemaItems =>
      allItems.where((i) => i.isCinema).toList();

  List<OfflineMediaItem> get animeItems =>
      allItems.where((i) => i.isAnime).toList();

  List<OfflineMediaItem> get mangaItems =>
      allItems.where((i) => i.isManga).toList();

  int get totalStorageBytes {
    return allItems.fold(0, (sum, item) {
      return sum + item.downloadedBytes;
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

  int get cinemaStorageBytes {
    return allItems
        .where((i) => i.isCinema)
        .fold(0, (sum, item) => sum + item.downloadedBytes);
  }

  String get formattedCinemaStorage {
    final bytes = cinemaStorageBytes;
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  int get animeStorageBytes {
    return allItems
        .where((i) => i.isAnime)
        .fold(0, (sum, item) => sum + item.downloadedBytes);
  }

  String get formattedAnimeStorage {
    final bytes = animeStorageBytes;
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  int get mangaStorageBytes {
    return allItems
        .where((i) => i.isManga)
        .fold(0, (sum, item) => sum + item.downloadedBytes);
  }

  String get formattedMangaStorage {
    final bytes = mangaStorageBytes;
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
        (AgentMode.isActive.value && AgentMode.useDemoData.value)) {
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
            _items[item.id] = item.status == OfflineDownloadStatus.downloading
                ? item.copyWith(status: OfflineDownloadStatus.paused)
                : item;
          }
        }
      }
    } catch (e) {
      Logger.e('OfflineMediaService: could not load stored registry', error: e);
    }
  }

  Future<void> _saveToStorage() async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      // In-memory only in demo mode: do not pollute user storage
      return;
    }
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
  }

  /// Exposes demo seeding directly for testing fixtures.
  @visibleForTesting
  void seedDemoData() {
    _seedDemoData();
  }

  bool isDownloaded(String id) {
    final item = _items[id];
    return item != null &&
        item.status == OfflineDownloadStatus.completed &&
        item.downloadedBytes > 0;
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
    int estimatedBytes = 0,
    Uint8List? directBytes,
  }) async {
    final existing = _items[id];
    if (existing != null &&
        existing.status == OfflineDownloadStatus.completed) {
      return;
    }

    final resolvedEstimated = estimatedBytes > 0
        ? estimatedBytes
        : (type == OfflineMediaType.movie
            ? 1400 * 1024 * 1024
            : 350 * 1024 * 1024);

    var effectiveUrl = sourceUrl;
    if ((effectiveUrl == null || effectiveUrl.isEmpty) &&
        (AgentMode.isActive.value && AgentMode.useDemoData.value)) {
      effectiveUrl =
          'https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4';
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
      sourceUrl: effectiveUrl,
      status: isCompletedDirect
          ? OfflineDownloadStatus.completed
          : OfflineDownloadStatus.downloading,
      progress: isCompletedDirect ? 1.0 : 0.05,
      totalBytes: isCompletedDirect
          ? directBytes.lengthInBytes
          : resolvedEstimated,
      downloadedBytes: isCompletedDirect
          ? directBytes.lengthInBytes
          : (resolvedEstimated * 0.05).round(),
      downloadedAt: DateTime.now(),
      durationSeconds: durationSeconds,
      blobKey: id,
    );

    _items[id] = initial;
    notifyListeners();
    await _saveToStorage();

    if (directBytes != null) {
      await _storage.saveMediaBlob(id, directBytes);
      final finalBytes = directBytes.lengthInBytes;
      _items[id] = initial.copyWith(
        status: OfflineDownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: finalBytes,
        totalBytes: finalBytes,
      );
      notifyListeners();
      await _saveToStorage();
      return;
    }

    if (effectiveUrl != null && effectiveUrl.startsWith('http')) {
      try {
        final res = await http
            .get(Uri.parse(effectiveUrl))
            .timeout(const Duration(minutes: 10));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          await _storage.saveMediaBlob(id, res.bodyBytes);
          _items[id] = initial.copyWith(
            status: OfflineDownloadStatus.completed,
            progress: 1.0,
            downloadedBytes: res.bodyBytes.lengthInBytes,
            totalBytes: res.bodyBytes.lengthInBytes,
          );
          notifyListeners();
          await _saveToStorage();
          return;
        }
      } catch (e) {
        Logger.e('Offline download failed for $id', error: e);
      }
    }

    // If download cannot be completed, mark failed
    _items[id] = initial.copyWith(
      status: OfflineDownloadStatus.failed,
      progress: 0.0,
      downloadedBytes: 0,
    );
    notifyListeners();
    await _saveToStorage();
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
    final id = mangaChapterId(slug, chapterId);
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

    if (pageUrls.isNotEmpty) {
      try {
        var saved = 0;
        var totalBytes = 0;
        for (var i = 0; i < pageUrls.length; i++) {
          final rawUrl = pageUrls[i];
          final pageKey = '${id}_p_${i + 1}';
          if (rawUrl.startsWith('http')) {
            final proxied = KatanaService.proxyImageUrl(rawUrl);
            final res = await http
                .get(Uri.parse(proxied))
                .timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              await _storage.saveMangaPage(pageKey, res.bodyBytes);
              saved++;
              totalBytes += res.bodyBytes.length;
            } else {
              Logger.e('Failed to fetch manga page $i ($proxied): status ${res.statusCode}');
            }
          } else if (rawUrl.startsWith('assets/')) {
            final data = await rootBundle.load(rawUrl);
            final bytes = data.buffer.asUint8List();
            await _storage.saveMangaPage(pageKey, bytes);
            saved++;
            totalBytes += bytes.length;
          }
          final progress = (saved / pageUrls.length).clamp(0.0, 1.0);
          _items[id] = _items[id]!.copyWith(
            progress: progress,
            downloadedBytes: totalBytes > 0
                ? totalBytes
                : (estimatedBytes * progress).round(),
          );
          notifyListeners();
        }
        if (saved == pageUrls.length && saved > 0) {
          _items[id] = _items[id]!.copyWith(
            status: OfflineDownloadStatus.completed,
            progress: 1.0,
            downloadedBytes: totalBytes > 0 ? totalBytes : estimatedBytes,
            totalBytes: totalBytes > 0 ? totalBytes : estimatedBytes,
          );
          notifyListeners();
          await _saveToStorage();
          return;
        }
      } catch (e) {
        Logger.e('Manga chapter download failed for $id', error: e);
      }
    }

    // If manga pages cannot be completed, clean up and mark failed
    for (var i = 1; i <= pageUrls.length; i++) {
      await _storage.deleteBlob('${id}_p_$i', isManga: true);
    }
    _items[id] = initial.copyWith(
      status: OfflineDownloadStatus.failed,
      progress: 0.0,
      downloadedBytes: 0,
    );
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> pauseDownload(String id) async {
    final item = _items[id];
    if (item == null) return;
    _items[id] = item.copyWith(status: OfflineDownloadStatus.paused);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> resumeDownload(String id) async {
    final item = _items[id];
    if (item == null) return;
    if (item.sourceUrl != null && item.sourceUrl!.isNotEmpty) {
      await startDownloadMedia(
        id: item.id,
        type: item.type,
        mediaId: item.mediaId,
        title: item.title,
        subtitle: item.subtitle,
        season: item.season,
        episode: item.episode,
        coverUrl: item.coverUrl,
        sourceUrl: item.sourceUrl,
        durationSeconds: item.durationSeconds,
      );
    } else if (item.isManga && item.pageUrls.isNotEmpty) {
      await startDownloadMangaChapter(
        slug: item.mediaId,
        mangaTitle: item.title,
        coverUrl: item.coverUrl,
        chapterId: item.chapterId ?? '1',
        chapterTitle: item.subtitle,
        pageUrls: item.pageUrls,
      );
    }
  }

  Future<void> deleteDownload(String id) async {
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
    if (type == null) {
      _items.clear();
      await _storage.clearAll();
    } else {
      final toRemove = _items.values
          .where((i) => i.type == type)
          .map((i) => i.id)
          .toList();
      for (final id in toRemove) {
        final item = _items.remove(id);
        if (item?.blobKey != null) {
          await _storage.deleteBlob(item!.blobKey!, isManga: item.isManga);
        }
        if (item != null && item.isManga) {
          for (var i = 1; i <= item.pageUrls.length; i++) {
            await _storage.deleteBlob('${item.id}_p_$i', isManga: true);
          }
        }
      }
    }
    notifyListeners();
    await _saveToStorage();
  }

  DateTime? _lastPositionSave;

  Future<void> updatePlaybackPosition(
    String id,
    int positionSeconds, {
    bool immediate = false,
  }) async {
    final item = _items[id];
    if (item == null) return;
    _items[id] = item.copyWith(lastPositionSeconds: positionSeconds);
    final now = DateTime.now();
    if (immediate ||
        _lastPositionSave == null ||
        now.difference(_lastPositionSave!).inSeconds >= 10) {
      _lastPositionSave = now;
      await _saveToStorage();
    }
  }

  Future<void> flushPlaybackPosition() async {
    await _saveToStorage();
  }

  Future<String?> getPlayableUrl(OfflineMediaItem item) async {
    if (item.blobKey != null) {
      final url = await _storage.getBlobUrl(item.blobKey!, isManga: item.isManga);
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
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
          'https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4',
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
          'https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4',
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
          'https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4',
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
          'https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4',
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
          'https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4',
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
          'https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4',
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
          'https://raw.githubusercontent.com/mediaelement/mediaelement-files/master/big_buck_bunny.mp4',
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
