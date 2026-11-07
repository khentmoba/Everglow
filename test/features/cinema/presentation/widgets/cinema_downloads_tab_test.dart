import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/services/offline_media/offline_media_item.dart';
import 'package:everglow/core/services/offline_media/offline_media_service.dart';
import 'package:everglow/core/services/offline_media/offline_media_storage.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/tabs/cinema_downloads_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CinemaDownloadsTab', () {
    late OfflineMediaStorage storage;
    late OfflineMediaService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AgentMode.isActive.value = false;
      AgentMode.useDemoData.value = false;
      storage = OfflineMediaStorage.instance;
      service = OfflineMediaService(storage: storage);
    });

    testWidgets('renders empty state when no cinema downloads exist', (
      tester,
    ) async {
      var browsed = false;

      await tester.runAsync(() async {
        await storage.clearAll();
        await service.clearAll();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OfflineMediaService>.value(
            value: service,
            child: Scaffold(
              body: CinemaDownloadsTab(
                onPlayMedia: (_) {},
                onBrowseCinema: () => browsed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('No Offline Downloads Yet'), findsOneWidget);
      expect(find.text('Explore Cinema'), findsOneWidget);

      await tester.tap(find.text('Explore Cinema'));
      await tester.pump();
      expect(browsed, isTrue);
    });

    testWidgets('renders populated cinema downloads', (tester) async {
      final item = OfflineMediaItem(
        id: 'cinema_movie_101',
        type: OfflineMediaType.movie,
        mediaId: '101',
        title: 'Interstellar',
        subtitle: 'Movie • 2014',
        durationSeconds: 7200,
        downloadedAt: DateTime.now(),
        status: OfflineDownloadStatus.completed,
      );

      final seriesItem = OfflineMediaItem(
        id: 'cinema_tv_202_s1_e1',
        type: OfflineMediaType.tv,
        mediaId: '202',
        title: 'Stranger Things',
        subtitle: 'S1 E1 • Chapter One',
        season: 1,
        episode: 1,
        durationSeconds: 3000,
        downloadedAt: DateTime.now(),
        status: OfflineDownloadStatus.completed,
      );

      await tester.runAsync(() async {
        await storage.clearAll();
        await service.clearAll();
        await service.startDownloadMedia(
          id: item.id,
          type: item.type,
          mediaId: item.mediaId,
          title: item.title,
          subtitle: item.subtitle,
          durationSeconds: item.durationSeconds,
          directBytes: Uint8List.fromList([1, 2]),
        );
        await service.startDownloadMedia(
          id: seriesItem.id,
          type: seriesItem.type,
          mediaId: seriesItem.mediaId,
          title: seriesItem.title,
          subtitle: seriesItem.subtitle,
          season: seriesItem.season,
          episode: seriesItem.episode,
          durationSeconds: seriesItem.durationSeconds,
          directBytes: Uint8List.fromList([3, 4]),
        );
      });

      MediaItem? playedMedia;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OfflineMediaService>.value(
            value: service,
            child: Scaffold(
              body: CinemaDownloadsTab(
                onPlayMedia: (m) => playedMedia = m,
                onBrowseCinema: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Offline Ready'), findsOneWidget);
      expect(find.text('TV Shows & Series'), findsOneWidget);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Stranger Things'), findsOneWidget);
      expect(find.text('Interstellar'), findsOneWidget);

      final playButtons = find.byIcon(Icons.play_circle_fill_rounded);
      expect(playButtons, findsWidgets);
      await tester.tap(playButtons.first);
      await tester.pump();

      expect(playedMedia, isNotNull);
      expect(playedMedia!.title, 'Stranger Things');
    });
  });
}
