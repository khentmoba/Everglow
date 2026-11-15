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
    expect(find.byTooltip('Dismiss'), findsNothing);
    expect(
      find.bySemanticsLabel('Dismiss update notification'),
      findsOneWidget,
    );

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

    await tester.tap(find.bySemanticsLabel('Dismiss update notification'));
    await tester.pumpAndSettle();

    expect(find.text('A fresh Everglow update is ready'), findsNothing);
    expect(browser.reloaded, isFalse);
    expect(service.isDismissed, isTrue);
  });

  testWidgets(
    'banner in MaterialApp.builder (above Overlay) never crashes on hover',
    (tester) async {
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

      final dismiss = find.byIcon(Icons.close_rounded);
      expect(dismiss, findsOneWidget);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: tester.getCenter(dismiss));
      await tester.pumpAndSettle();

      expect(find.text('A fresh Everglow update is ready'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final textSize = tester.getSize(
        find.text('A fresh Everglow update is ready'),
      );
      expect(textSize.width, greaterThan(100));

      await gesture.removePointer();
      await tester.pumpAndSettle();
    },
  );
}
