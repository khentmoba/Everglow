import 'package:everglow/features/jukebox/data/models/music_status.dart';
import 'package:everglow/features/jukebox/data/services/spotify_auth_service.dart';
import 'package:everglow/features/jukebox/data/services/spotify_player_service.dart';
import 'package:everglow/features/jukebox/presentation/providers/jukebox_provider.dart';
import 'package:everglow/features/jukebox/presentation/widgets/jukebox_widget.dart';
import 'package:everglow/features/jukebox/presentation/widgets/stats_fx.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Jukebox extends ChangeNotifier implements JukeboxProvider {
  @override
  Stream<Map<String, MusicStatus>> get statusStream => Stream.value({});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpotifyAuth extends ChangeNotifier implements SpotifyAuthService {
  @override
  bool get isLinked => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpotifyPlayer extends ChangeNotifier implements SpotifyPlayerService {
  @override
  String? get deviceId => null;
  @override
  String? get error => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('idle phone jukebox settles without continuously repainting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final font = FontLoader('Outfit');
    font.addFont(rootBundle.load('assets/google_fonts/Outfit-Medium.ttf'));
    await tester.runAsync(font.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<JukeboxProvider>(create: (_) => _Jukebox()),
          ChangeNotifierProvider<SpotifyAuthService>(
            create: (_) => _SpotifyAuth(),
          ),
          ChangeNotifierProvider<SpotifyPlayerService>(
            create: (_) => _SpotifyPlayer(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: JukeboxWidget())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('JUKEBOX'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('phone leaderboard effects settle and resume on tablet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            children: [
              StatsShimmer(color: AppColors.deepRose),
              StatsSparkleBadge(color: AppColors.deepRose),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.view.physicalSize = const Size(810, 1080);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
