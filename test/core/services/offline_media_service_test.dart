import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/services/offline_media/offline_media_item.dart';
import 'package:everglow/core/services/offline_media/offline_media_service.dart';
import 'package:everglow/core/services/offline_media/offline_media_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineMediaItem', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime.now();
      final item = OfflineMediaItem(
        id: 'cinema_movie_100',
        type: OfflineMediaType.movie,
        mediaId: '100',
        title: 'Test Movie',
        subtitle: 'Movie • 2024',
        coverUrl: 'https://example.com/cover.jpg',
        sourceUrl: 'https://example.com/stream.mp4',
        status: OfflineDownloadStatus.completed,
        progress: 1.0,
        totalBytes: 500 * 1024 * 1024,
        downloadedBytes: 500 * 1024 * 1024,
        downloadedAt: now,
        durationSeconds: 7200,
        lastPositionSeconds: 1500,
      );

      final json = item.toJson();
      final restored = OfflineMediaItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.type, OfflineMediaType.movie);
      expect(restored.title, 'Test Movie');
      expect(restored.isCinema, isTrue);
      expect(restored.isAnime, isFalse);
      expect(restored.isManga, isFalse);
      expect(restored.formattedSize, contains('500.0 MB'));
      expect(restored.formattedDuration, '2h 0m');
      expect(restored.formattedProgress, '100%');
    });

    test('formats progress and sizes gracefully', () {
      final item = OfflineMediaItem(
        id: 'tv_1',
        type: OfflineMediaType.tv,
        mediaId: '200',
        title: 'Test Series',
        season: 1,
        episode: 3,
        progress: 0.456,
        totalBytes: 1024 * 1024 * 1024 * 2, // 2 GB
        downloadedAt: DateTime.now(),
      );

      expect(item.formattedProgress, '45%');
      expect(item.formattedSize, '2.00 GB');
      expect(item.isEpisode, isTrue);
    });
  });

  group('OfflineMediaService', () {
    late OfflineMediaStorage storage;
    late OfflineMediaService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AgentMode.isActive.value = false;
      AgentMode.useDemoData.value = false;
      storage = OfflineMediaStorage.instance;
      await storage.clearAll();
      service = OfflineMediaService(storage: storage);
    });

    test('downloads a media item with direct bytes', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      await service.startDownloadMedia(
        id: 'cinema_movie_99',
        type: OfflineMediaType.movie,
        mediaId: '99',
        title: 'Direct Movie',
        directBytes: fakeBytes,
        durationSeconds: 3600,
      );

      expect(service.isDownloaded('cinema_movie_99'), isTrue);
      final item = service.getItem('cinema_movie_99');
      expect(item, isNotNull);
      expect(item!.status, OfflineDownloadStatus.completed);
      expect(item.totalBytes, 5);

      final hasBlob = await storage.hasBlob('cinema_movie_99');
      expect(hasBlob, isTrue);
    });

    test('manages multiple episodes for a series across seasons', () async {
      final ep1Bytes = Uint8List.fromList([10, 20]);
      final ep2Bytes = Uint8List.fromList([30, 40]);

      await service.startDownloadMedia(
        id: 'tv_show_1_s1_e1',
        type: OfflineMediaType.tv,
        mediaId: 'show_1',
        title: 'Show One',
        subtitle: 'S1 E1',
        season: 1,
        episode: 1,
        directBytes: ep1Bytes,
      );

      await service.startDownloadMedia(
        id: 'tv_show_1_s1_e2',
        type: OfflineMediaType.tv,
        mediaId: 'show_1',
        title: 'Show One',
        subtitle: 'S1 E2',
        season: 1,
        episode: 2,
        directBytes: ep2Bytes,
      );

      final s1Episodes = service.getEpisodesForSeries('show_1', season: 1);
      expect(s1Episodes.length, 2);
      expect(s1Episodes[0].episode, 1);
      expect(s1Episodes[1].episode, 2);
    });

    test('downloads and stores manga chapter pages', () async {
      final p1 = Uint8List.fromList([100]);
      final p2 = Uint8List.fromList([200]);

      await service.startDownloadMangaChapter(
        slug: 'one-punch',
        mangaTitle: 'One Punch',
        coverUrl: 'https://example.com/cover.jpg',
        chapterId: '1',
        chapterTitle: 'Chapter 1: Power',
        pageUrls: ['page1.jpg', 'page2.jpg'],
        pageBytesList: [p1, p2],
      );

      final chapters = service.getChaptersForManga('one-punch');
      expect(chapters.length, 1);
      expect(chapters.first.isCompleted, isTrue);
      expect(chapters.first.pageUrls.length, 2);

      final pageUrl = await service.getMangaPageUrl('manga_one-punch_ch_1', 1);
      expect(pageUrl, isNotNull);
    });

    test('downloads manga chapter via pageUrls and asserts consistent ID', () async {
      await service.startDownloadMangaChapter(
        slug: 'one-piece',
        mangaTitle: 'One Piece',
        coverUrl: 'https://example.com/cover.jpg',
        chapterId: '1000',
        chapterTitle: 'Chapter 1000',
        pageUrls: ['assets/data/guardian_messages_seed.json'],
      );

      final expectedId = 'manga_one-piece_ch_1000';
      final item = service.getItem(expectedId);
      expect(item, isNotNull);
      expect(item!.isCompleted, isTrue);
      expect(service.isDownloaded(expectedId), isTrue);
      expect(item.progress, 1.0);
    });

    test('deleting download clears storage and registry', () async {
      final bytes = Uint8List.fromList([1, 2]);
      await service.startDownloadMedia(
        id: 'cinema_movie_test_del',
        type: OfflineMediaType.movie,
        mediaId: 'test_del',
        title: 'To Delete',
        directBytes: bytes,
      );

      expect(service.isDownloaded('cinema_movie_test_del'), isTrue);
      await service.deleteDownload('cinema_movie_test_del');
      expect(service.isDownloaded('cinema_movie_test_del'), isFalse);
      expect(await storage.hasBlob('cinema_movie_test_del'), isFalse);
    });
  });
}
