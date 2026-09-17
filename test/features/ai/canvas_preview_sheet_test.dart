import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/ai/data/services/study_artifact.dart';
import 'package:everglow/features/ai/presentation/widgets/canvas_preview_sheet.dart';

void main() {
  group('CanvasPreviewSheet save button', () {
    testWidgets('tapping save attempts the save and shows feedback',
        (tester) async {
      // Widget tests report Android, which would build a real WebView for
      // the preview frame — macOS renders the placeholder instead.
      // (Reset at the end of the body: the binding checks debug vars
      // before tearDowns run.)
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      const app = HtmlArtifact(title: 'Tap Star', html: '<p>game</p>');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CanvasPreviewSheet(app: app, expanded: true),
          ),
        ),
      );

      expect(find.text('Tap Star'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);

      // No auth session or Firestore in tests, so the save fails soft with
      // the friendly snackbar — the tap itself must still fire.
      await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
      await tester.pump();

      expect(find.text('Could not save — try again?'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
