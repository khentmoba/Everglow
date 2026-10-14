import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/shared/widgets/shelf/media_section_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class _Auth extends ChangeNotifier implements AuthService {
  _Auth(this.isCinemaOnlyUser);

  @override
  final bool isCinemaOnlyUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('guests can move between every media section on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _Auth(true);
    final router = GoRouter(
      initialLocation: '/cinema',
      routes: [
        for (final route in ['/cinema', '/anime', '/manga', '/books'])
          GoRoute(
            path: route,
            builder: (_, _) => Scaffold(
              appBar: AppBar(actions: [MediaSectionMenu(currentRoute: route)]),
              body: Text(route),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    for (final (from, fromLabel) in [
      ('/cinema', 'Cinema'),
      ('/anime', 'Anime'),
      ('/manga', 'Mangacelestia'),
      ('/books', 'Books'),
    ]) {
      for (final (to, label) in [
        ('/cinema', 'Cinema'),
        ('/anime', 'Anime'),
        ('/manga', 'Mangacelestia'),
        ('/books', 'Books'),
      ]) {
        if (from == to) continue;
        router.go(from);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Switch section'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PopupMenuItem<String>>(
                find.ancestor(
                  of: find.text(fromLabel),
                  matching: find.byType(PopupMenuItem<String>),
                ),
              )
              .enabled,
          isFalse,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(to), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('couple navigation is unchanged', (tester) async {
    final auth = _Auth(false);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: const MaterialApp(
          home: Scaffold(body: MediaSectionMenu(currentRoute: '/cinema')),
        ),
      ),
    );
    expect(find.byTooltip('Switch section'), findsNothing);
  });
}
