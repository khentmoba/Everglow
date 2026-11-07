import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/services/offline_media/offline_media_service.dart';
import 'package:everglow/core/services/offline_media/offline_media_storage.dart';
import 'package:everglow/features/manga/presentation/screens/katana_downloads_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KatanaDownloadsScreen', () {
    late OfflineMediaStorage storage;
    late OfflineMediaService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AgentMode.isActive.value = false;
      AgentMode.useDemoData.value = false;
      storage = OfflineMediaStorage.instance;
      service = OfflineMediaService(storage: storage);
    });

    testWidgets('renders empty state when no manga downloads exist', (
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
            child: const KatanaDownloadsScreen(embed: true),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Downloads'), findsOneWidget);
      expect(
        find.text('No Offline Manga Chapters Downloaded Yet'),
        findsOneWidget,
      );
      expect(find.text('Explore Manga Celestia'), findsOneWidget);
    });

    testWidgets(
      'renders downloaded manga chapters grouped by series and allows reading',
      (tester) async {
        final p1 = Uint8List.fromList([1, 2]);
        final p2 = Uint8List.fromList([3, 4]);

        await tester.runAsync(() async {
          await storage.clearAll();
          await service.clearAll();
          await service.startDownloadMangaChapter(
            slug: 'solo-leveling',
            mangaTitle: 'Solo Leveling',
            coverUrl: 'assets/images/demo/poster-1.jpg',
            chapterId: '1',
            chapterTitle: 'Chapter 1: I\'m Used to It',
            pageUrls: const ['assets/images/demo/poster-1.jpg'],
            pageBytesList: [p1],
          );
          await service.startDownloadMangaChapter(
            slug: 'solo-leveling',
            mangaTitle: 'Solo Leveling',
            coverUrl: 'assets/images/demo/poster-1.jpg',
            chapterId: '2',
            chapterTitle: 'Chapter 2: The Double Dungeon',
            pageUrls: const ['assets/images/demo/poster-2.jpg'],
            pageBytesList: [p2],
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<OfflineMediaService>.value(
              value: service,
              child: const KatanaDownloadsScreen(embed: true),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Offline Ready'), findsOneWidget);
        expect(find.text('Solo Leveling'), findsOneWidget);
        expect(find.text('2 downloaded chapters'), findsOneWidget);
        expect(find.text('CH 1'), findsOneWidget);
        expect(find.text('CH 2'), findsOneWidget);
        expect(find.text('Chapter 1: I\'m Used to It'), findsOneWidget);
        expect(find.text('Chapter 2: The Double Dungeon'), findsOneWidget);

        final readButtons = find.byTooltip('Read chapter');
        expect(readButtons, findsWidgets);
      },
    );
  });
}
