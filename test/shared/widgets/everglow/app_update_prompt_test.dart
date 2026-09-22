import 'package:everglow/core/system/app_update_browser.dart';
import 'package:everglow/core/system/app_update_service.dart';
import 'package:everglow/shared/widgets/everglow/app_update_prompt.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePromptBrowser implements AppUpdateBrowser {
  bool reloaded = false;

  @override
  bool get supported => true;
  @override
  bool get isHidden => false;
  @override
  bool get isOffline => false;
  @override
  bool get isVideoPlaying => false;

  @override
  void reload() {
    reloaded = true;
  }

  @override
  void Function() listen({
    required void Function() onHidden,
    required void Function() onVisible,
    required void Function() onOnline,
  }) =>
      () {};
}

void main() {
  testWidgets('does not show banner when no update is available', (tester) async {
    final browser = FakePromptBrowser();
    final service = AppUpdateService(browser: browser);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppUpdatePrompt(
          service: service,
          child: const Scaffold(body: Text('App Content')),
        ),
      ),
    );

    expect(find.text('App Content'), findsOneWidget);
    expect(find.text('A fresh Everglow update is ready'), findsNothing);
    expect(find.text('Restart'), findsNothing);
  });

  testWidgets('shows banner when update is available and allows restart', (tester) async {
    final browser = FakePromptBrowser();
    final service = AppUpdateService(browser: browser);
    addTearDown(service.dispose);

    await service.noteLiveBuild('1.0.0');
    await service.noteLiveBuild('2.0.0');

    await tester.pumpWidget(
      MaterialApp(
        home: AppUpdatePrompt(
          service: service,
          child: const Scaffold(body: Text('App Content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A fresh Everglow update is ready'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    // No Tooltip: the banner lives above Overlay (see builder test below),
    // so Dismiss is exposed via Semantics instead.
    expect(find.byTooltip('Dismiss'), findsNothing);
    expect(
      find.bySemanticsLabel('Dismiss update notification'),
      findsOneWidget,
    );

    // Tap Restart -> triggers reload
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(browser.reloaded, isTrue);
  });

  testWidgets('tapping dismiss hides the banner without reloading', (tester) async {
    final browser = FakePromptBrowser();
    final service = AppUpdateService(browser: browser);
    addTearDown(service.dispose);

    await service.noteLiveBuild('1.0.0');
    await service.noteLiveBuild('2.0.0');

    await tester.pumpWidget(
      MaterialApp(
        home: AppUpdatePrompt(
          service: service,
          child: const Scaffold(body: Text('App Content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A fresh Everglow update is ready'), findsOneWidget);

    // Tap Dismiss -> banner disappears, browser does NOT reload
    await tester.tap(find.bySemanticsLabel('Dismiss update notification'));
    await tester.pumpAndSettle();

    expect(find.text('A fresh Everglow update is ready'), findsNothing);
    expect(browser.reloaded, isFalse);
    expect(service.isDismissed, isTrue);
  });

  testWidgets(
    'banner in MaterialApp.builder (above Overlay) never crashes on hover',
    (tester) async {
      // Production setup (see EverglowApp.build in main.dart): the prompt
      // wraps the Navigator via MaterialApp.builder, so it sits ABOVE the
      // Overlay. Any Tooltip there throws "No Overlay widget found" on
      // hover in release (assert in debug) and squeezes the Row into
      // vertical text + a 340px tall slab. This test pins the fix.
      final browser = FakePromptBrowser();
      final service = AppUpdateService(browser: browser);
      addTearDown(service.dispose);

      await service.noteLiveBuild('1.0.0');
      await service.noteLiveBuild('2.0.0');
      expect(service.updateAvailable, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => AppUpdatePrompt(
            service: service,
            child: child!,
          ),
          home: const Scaffold(body: Text('App Content')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A fresh Everglow update is ready'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
      expect(tester.takeException(), isNull);

      // Desktop/tablet mouse hover over Dismiss — the exact gesture that
      // crashed live with "No Overlay widget found".
      final dismiss = find.byIcon(Icons.close_rounded);
      expect(dismiss, findsOneWidget);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: tester.getCenter(dismiss));
      await tester.pumpAndSettle();

      expect(find.text('A fresh Everglow update is ready'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Banner text stays horizontal (wide), never squeezed vertical.
      final textSize = tester.getSize(
        find.text('A fresh Everglow update is ready'),
      );
      expect(textSize.width, greaterThan(100));

      await gesture.removePointer();
      await tester.pumpAndSettle();
    },
  );
}
