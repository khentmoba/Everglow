@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:everglow/core/system/desktop_app.dart';
import 'package:everglow/shared/widgets/everglow/desktop_app_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('__everglowDesktopVersion')
external set _version(JSString? value);
@JS('__everglowCheckForUpdates')
external set _check(JSFunction value);

void main() {
  tearDown(() => _version = null);
  test(
    'missing bridge is a browser; desktop bridge invokes the fixed action',
    () {
      expect(DesktopApp.version, isNull);
      var checks = 0;
      _version = '0.3.0'.toJS;
      _check = (() {
        checks++;
      }).toJS;
      expect(DesktopApp.version, '0.3.0');
      DesktopApp.checkForUpdates();
      expect(checks, 1);
      _version = null;
    },
  );
  testWidgets(
    'desktop action displays native version and requests its updater',
    (tester) async {
      var checks = 0;
      _version = '0.3.0'.toJS;
      _check = (() {
        checks++;
      }).toJS;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DesktopAppAction())),
      );
      expect(find.text('Everglow Desktop 0.3.0'), findsOneWidget);
      expect(find.text('Download for Windows'), findsNothing);
      await tester.tap(find.text('Check for desktop updates'));
      await tester.pump();
      expect(checks, 1);
    },
  );
}
