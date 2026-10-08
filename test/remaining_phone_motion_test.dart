import 'package:everglow/features/daily_bloom/data/models/plant_type.dart';
import 'package:everglow/features/daily_bloom/presentation/widgets/garden_plant_view.dart';
import 'package:everglow/features/daily_bloom/presentation/widgets/garden_weather_overlay.dart';
import 'package:everglow/features/entry/presentation/widgets/animated_door.dart';
import 'package:everglow/features/entry/presentation/widgets/petal_shower.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_badges.dart';
import 'package:everglow/features/starlight_jar/presentation/screens/starlight_jar_widget.dart';
import 'package:everglow/features/starlight_jar/domain/models/star_note.dart';
import 'package:everglow/features/jukebox/presentation/widgets/stats_leaderboard_header.dart';
import 'package:everglow/shared/widgets/everglow/everglow_background.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/google_fonts/Outfit-Medium.ttf'));
    await font.load();
  });
  testWidgets('phone leaderboard and optional backdrop petals stay still', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              EverglowBackground(showPetals: true),
              LeaderboardHeader(
                displayName: 'Demo',
                username: 'demo',
                totalPlays: 1200,
                isLeader: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1ST'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.view.physicalSize = const Size(810, 1080);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('phone star jar settles with notes still visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: StarlightJarWidget(
                previewNotes: [
                  StarNote(
                    id: 'demo',
                    content: 'A demo memory',
                    author: 'Demo',
                    timestamp: DateTime(2026),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1 star'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('phone garden and airing decoration settles; plants still grow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stage = ValueNotifier(3);
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const GardenWeatherOverlay(season: 3),
            SizedBox(
              width: 200,
              height: 250,
              child: ValueListenableBuilder<int>(
                valueListenable: stage,
                builder: (_, value, _) => GardenPlantView(
                  plantType: PlantType.all.first,
                  stage: value,
                ),
              ),
            ),
            statusBadge('AIRING'),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    stage.value = 5;
    await tester.pump();
    expect(find.byKey(const ValueKey('lily-5')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.view.physicalSize = const Size(810, 1080);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('phone doorway settles after entrance and still unlocks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final unlocked = ValueNotifier(false);
    addTearDown(unlocked.dispose);
    int entrances = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: unlocked,
          builder: (_, value, _) => AnimatedDoor(
            isUnlocked: value,
            onEntranceComplete: () => entrances++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(entrances, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    unlocked.value = true;
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('hidden petal shower does not request tablet frames', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(810, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, value, _) => PetalShower(isVisible: value),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    visible.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
