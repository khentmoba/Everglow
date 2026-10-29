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
      'Text inside a dialog can be selected and copied',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final popupFocus = FocusNode(
          canRequestFocus: false,
          skipTraversal: true,
        );
        addTearDown(popupFocus.dispose);
        try {
          // Same shape as the app: EverglowApp's builder holds an outer
          // SelectionArea for dialogs, and each page has its own (ShellRoute).
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => Overlay.wrap(
                child: SelectionArea(focusNode: popupFocus, child: child!),
              ),
              home: Builder(
                builder: (context) => SelectionArea(
                  child: Scaffold(
                    body: Stack(
                      children: [
                        const Center(child: Text('The Lantern Trail')),
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => const Dialog(
                              child: Text('Moonlit Cinema'),
                            ),
                          ),
                          child: const Text('More Info'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('More Info'));
          await tester.pumpAndSettle();

          final title = find.text('Moonlit Cinema');
          final drag = await tester.startGesture(
            tester.getTopLeft(title),
            kind: PointerDeviceKind.mouse,
          );
          await drag.moveTo(tester.getBottomRight(title));
          await drag.up();
          await tester.pumpAndSettle();

          final rightClick = await tester.startGesture(
            tester.getCenter(title),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await rightClick.up();
          await tester.pumpAndSettle();

          await tester.tap(find.text('Copy'));
          await tester.pumpAndSettle();

          // Only the dialog's text, not the page text behind it.
          expect(mockClipboard['text'], 'Moonlit Cinema');

          // Selecting must not steal focus: Escape still closes the dialog.
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(title, findsNothing);
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
