import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Text Selection and Copying', () {
    late Map<String, dynamic> mockClipboard;

    setUp(() {
      mockClipboard = <String, dynamic>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            mockClipboard['text'] = (call.arguments as Map)['text'];
            return null;
          } else if (call.method == 'Clipboard.getData') {
            return mockClipboard;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets(
      'Desktop right-click on active text selection shows Copy button and copies text',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: SelectionArea(
                  child: Center(
                    child: Text('Everglow Love Letter Synopsis'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final textFinder = find.text('Everglow Love Letter Synopsis');
          expect(textFinder, findsOneWidget);

          // Drag mouse across text to select it
          final topLeft = tester.getTopLeft(textFinder);
          final bottomRight = tester.getBottomRight(textFinder);

          final dragGesture = await tester.startGesture(
            topLeft,
            kind: PointerDeviceKind.mouse,
          );
          await dragGesture.moveTo(bottomRight);
          await dragGesture.up();
          await tester.pumpAndSettle();

          // Right click on the active selection
          final center = tester.getCenter(textFinder);
          final rightClickGesture = await tester.startGesture(
            center,
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await rightClickGesture.up();
          await tester.pumpAndSettle();

          // The desktop context menu toolbar must show "Copy"
          final copyFinder = find.text('Copy');
          expect(copyFinder, findsOneWidget);

          // Tapping "Copy" copies the selected text to clipboard
          await tester.tap(copyFinder);
          await tester.pumpAndSettle();

          expect(mockClipboard['text'], 'Everglow Love Letter Synopsis');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'Mobile touch long-press shows Copy button and copies word to clipboard',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: SelectionArea(
                  child: Center(
                    child: Text('Everglow Love Letter Synopsis'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final textFinder = find.text('Everglow Love Letter Synopsis');
          expect(textFinder, findsOneWidget);

          // Long press on text
          final center = tester.getCenter(textFinder);
          final gesture = await tester.startGesture(center, pointer: 1);
          await tester.pump(const Duration(milliseconds: 700));
          await gesture.up();
          await tester.pumpAndSettle();

          // Mobile toolbar must show "Copy"
          final copyFinder = find.text('Copy');
          expect(copyFinder, findsOneWidget);

          // Tap "Copy"
          await tester.tap(copyFinder);
          await tester.pumpAndSettle();

          expect(mockClipboard['text'], isNotEmpty);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    test(
      'BrowserContextMenu.disableContextMenu disables browser context menu on web',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.contextMenu, (call) async {
          expect(call.method, 'disableContextMenu');
          return null;
        });

        await BrowserContextMenu.disableContextMenu();
        expect(BrowserContextMenu.enabled, isFalse);
      },
      skip: !kIsWeb,
    );
  });
}
