import 'package:everglow/shared/widgets/everglow/desktop_app_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  String? opened;
  var succeeds = true;
  setUp(() {
    opened = null;
    succeeds = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          opened = (call.arguments as Map)['url'] as String?;
          return succeeds;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets(
    'Windows offers the stable installer and a legacy update path',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DesktopAppAction())),
      );
      expect(find.textContaining('Already installed?'), findsOneWidget);
      await tester.tap(find.text('Download for Windows'));
      await tester.pump();
      expect(opened, DesktopAppAction.downloadUrl.toString());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('phone opens release information instead of downloading an exe', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DesktopAppAction())),
    );
    await tester.tap(find.text('Everglow for Windows'));
    await tester.pump();
    expect(opened, DesktopAppAction.releasesUrl.toString());
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed link shows a retryable error', (tester) async {
    succeeds = false;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DesktopAppAction())),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('Could not open it. Please try again.'), findsOneWidget);
    succeeds = true;
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('Could not open it. Please try again.'), findsNothing);
  });
}
