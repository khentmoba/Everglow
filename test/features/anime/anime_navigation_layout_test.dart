import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/anime/data/services/animex_stores.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_nav.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _DemoAuth extends ChangeNotifier implements AuthService {
  @override
  String get currentUser => 'Demo profile';
  @override
  bool get isCoupleUser => true;
  @override
  bool get isCinemaOnlyUser => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [320.0, 430.0, 820.0, 1199.0, 1200.0, 1440.0]) {
    testWidgets('anime navigation fits and search works at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      for (final (family, file) in [
        ('Bebas Neue', 'BebasNeue-Regular.ttf'),
        ('DM Sans', 'DMSans-Regular.ttf'),
      ]) {
        final loader = FontLoader(family)
          ..addFont(rootBundle.load('assets/google_fonts/$file'));
        await tester.runAsync(loader.load);
      }
      final auth = _DemoAuth();
      final controller = AnimeXController();
      addTearDown(() {
        tester.view.reset();
        auth.dispose();
        controller.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<AnimexStores>.value(
              value: AnimexStores.instance,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AnimeXTopHeader(
                controller: controller,
                onSearch: () => controller.goTo(AnimexPage.search),
              ),
              bottomNavigationBar: width < AnimeXTokens.desktopNavBreakpoint
                  ? AnimeXMobileBottomNav(
                      controller: controller,
                      onSearch: () => controller.goTo(AnimexPage.search),
                    )
                  : null,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (width >= 768) {
        expect(find.text('EN'), findsOneWidget);
        expect(find.text('JP'), findsOneWidget);
      }
      final search = find.byTooltip('Search');
      final rect = tester.getRect(search);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(width));
      await tester.tap(search);
      expect(controller.page, AnimexPage.search);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('bottom navigation clears the system home indicator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    final controller = AnimeXController();
    addTearDown(() {
      tester.view.reset();
      controller.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AnimeXMobileBottomNav(
            controller: controller,
            onSearch: () => controller.goTo(AnimexPage.search),
          ),
        ),
      ),
    );
    final history = tester.getRect(find.text('History'));
    expect(history.bottom, lessThanOrEqualTo(898));
    await tester.tap(find.text('My List'));
    expect(controller.page, AnimexPage.myList);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
