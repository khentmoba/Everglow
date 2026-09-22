import 'package:everglow/core/system/app_update_browser.dart';
import 'package:everglow/core/system/app_update_service.dart';
import 'package:everglow/shared/widgets/everglow/app_update_prompt.dart';
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
    expect(find.byTooltip('Dismiss'), findsOneWidget);

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
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('A fresh Everglow update is ready'), findsNothing);
    expect(browser.reloaded, isFalse);
    expect(service.isDismissed, isTrue);
  });
}
