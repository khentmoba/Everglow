import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/anime/data/services/animex_stores.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_home_page.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_nav.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_tokens.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

class _DemoAuth extends ChangeNotifier implements AuthService {
  @override
  String get currentUser => 'Demo';
  @override
  bool get isCoupleUser => true;
  @override
  bool get isCinemaOnlyUser => false;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _DemoAnime extends MediaItem {
  final int index;
  _DemoAnime(this.index, String title)
    : super(
        id: 'demo-$index',
        tmdbId: index + 1,
        title: title,
        mediaType: 'tv',
        posterPath: '',
        backdropPath: '',
        year: '2026',
        status: '',
        isAnime: true,
        source: 'tmdb',
        addedAt: DateTime(2026),
        score: 8.4,
        episodeCount: 12,
        airingStatus: 'RELEASING',
        format: 'TV',
        genres: ['Adventure', 'Fantasy'],
        synopsis:
            'A young mapmaker follows a trail of forgotten stars, discovering unlikely friends and a world beyond the edge of her atlas.',
      );
  @override
  String get posterUrl => 'assets/images/demo/poster-${index % 4 + 1}.jpg';
  @override
  String get backdropUrl => posterUrl;
}

void main() {
  testWidgets(
    'anime home keeps discovery visible on phone, tablet and desktop',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = _DemoAuth();
      final controller = AnimeXController();
      for (final (family, file) in [
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
        ('Bebas Neue', 'assets/google_fonts/BebasNeue-Regular.ttf'),
        ('DM Sans', 'assets/google_fonts/DMSans-Regular.ttf'),
      ]) {
        final loader = FontLoader(family)..addFont(rootBundle.load(file));
        await tester.runAsync(loader.load);
      }
      final items = [
        for (final (i, title) in [
          'The Lantern Atlas',
          'Summer Above the Clouds',
          'Moonlit Express',
          'The Last Stargazer',
          'Beyond the Blue',
          'A Little Magic',
        ].indexed)
          _DemoAnime(i, title),
      ];
      for (final size in [
        const Size(430, 932),
        const Size(820, 1180),
        const Size(1440, 1000),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthService>.value(value: auth),
              ChangeNotifierProvider<AnimexStores>.value(
                value: AnimexStores.instance,
              ),
            ],
            child: MaterialApp(
              home: RepaintBoundary(
                key: const ValueKey('proof'),
                child: Scaffold(
                  backgroundColor: AnimeXTokens.bg,
                  body: Column(
                    children: [
                      AnimeXTopHeader(controller: controller, onSearch: () {}),
                      Expanded(
                        child: AnimeXHomePage(
                          controller: controller,
                          loadRow: (_) async => AnimexMediaPage(
                            items: items,
                            scores: const [],
                            currentPage: 1,
                            hasNextPage: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  bottomNavigationBar:
                      size.width < AnimeXTokens.desktopNavBreakpoint
                      ? AnimeXMobileBottomNav(
                          controller: controller,
                          onSearch: () {},
                        )
                      : null,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        final heading = tester.getRect(find.text('Trending This Week'));
        expect(
          heading.bottom,
          lessThan(size.height - AnimeXTokens.mobileNavHeight),
        );
        const outputDir = String.fromEnvironment('PR_PROOF_DIR');
        if (outputDir.isNotEmpty) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('proof')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final pixels = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final png = img.encodePng(
              img.Image.fromBytes(
                width: image.width,
                height: image.height,
                bytes: pixels!.buffer,
                bytesOffset: pixels.offsetInBytes,
                numChannels: 4,
              ),
            );
            final path = File('$outputDir/after-${size.width.toInt()}.png');
            await path.parent.create(recursive: true);
            await path.writeAsBytes(png);
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
      tester.view.reset();
      controller.dispose();
      auth.dispose();
    },
  );
}
