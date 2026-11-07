import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/services/offline_media/offline_media_item.dart';
import 'package:everglow/core/services/offline_media/offline_media_service.dart';
import 'package:everglow/core/services/offline_media/offline_media_storage.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_downloads_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnimeXDownloadsPage', () {
    late OfflineMediaStorage storage;
    late OfflineMediaService service;
    late AnimeXController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AgentMode.isActive.value = false;
      AgentMode.useDemoData.value = false;
      storage = OfflineMediaStorage.instance;
      service = OfflineMediaService(storage: storage);
      controller = AnimeXController();
    });

    testWidgets('renders empty state when no anime downloads exist', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await storage.clearAll();
        await service.clearAll();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OfflineMediaService>.value(
            value: service,
            child: Scaffold(
              body: AnimeXDownloadsPage(controller: controller),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('No Offline Anime Downloaded Yet'), findsOneWidget);
      expect(find.text('Explore Anime'), findsOneWidget);

      await tester.tap(find.text('Explore Anime'));
      await tester.pump();
      expect(controller.page, AnimexPage.home);
    });

    testWidgets(
      'renders downloaded anime episodes across seasons and allows playback',
      (tester) async {
        final ep1 = OfflineMediaItem(
          id: 'anime_154587_s1_e1',
          type: OfflineMediaType.anime,
          mediaId: '154587',
          title: 'Frieren: Beyond Journey\'s End',
          subtitle: 'Episode 1 • The Journey\'s End',
          season: 1,
          episode: 1,
          durationSeconds: 1440,
          downloadedAt: DateTime.now(),
          status: OfflineDownloadStatus.completed,
        );

        final ep2 = OfflineMediaItem(
          id: 'anime_154587_s1_e2',
          type: OfflineMediaType.anime,
          mediaId: '154587',
          title: 'Frieren: Beyond Journey\'s End',
          subtitle: 'Episode 2 • It Didn\'t Have to Be Magic...',
          season: 1,
          episode: 2,
          durationSeconds: 1440,
          downloadedAt: DateTime.now(),
          status: OfflineDownloadStatus.completed,
        );

        await tester.runAsync(() async {
          await storage.clearAll();
          await service.clearAll();
          await service.startDownloadMedia(
            id: ep1.id,
            type: ep1.type,
            mediaId: ep1.mediaId,
            title: ep1.title,
            subtitle: ep1.subtitle,
            season: ep1.season,
            episode: ep1.episode,
            durationSeconds: ep1.durationSeconds,
            directBytes: Uint8List.fromList([10, 20]),
          );
          await service.startDownloadMedia(
            id: ep2.id,
            type: ep2.type,
            mediaId: ep2.mediaId,
            title: ep2.title,
            subtitle: ep2.subtitle,
            season: ep2.season,
            episode: ep2.episode,
            durationSeconds: ep2.durationSeconds,
            directBytes: Uint8List.fromList([30, 40]),
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<OfflineMediaService>.value(
              value: service,
              child: Scaffold(
                body: AnimeXDownloadsPage(controller: controller),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Offline Ready'), findsOneWidget);
        expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);
        expect(find.text('2 downloaded episodes'), findsOneWidget);
        expect(find.text('EP 1'), findsOneWidget);
        expect(find.text('EP 2'), findsOneWidget);

        final playButtons = find.byIcon(Icons.play_circle_fill_rounded);
        expect(playButtons, findsWidgets);
        await tester.tap(playButtons.first);
        await tester.pump();

        expect(controller.watchItem, isNotNull);
        expect(controller.watchItem!.title, 'Frieren: Beyond Journey\'s End');
        expect(controller.watchEpisode, 1);
      },
    );
  });
}
