@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:everglow/core/system/web_standalone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('eval')
external JSAny? _eval(JSString script);

void js(String script) => _eval(script.toJS);

void main() {
  setUp(() {
    js('''
      window.egOriginalStyle = window.getComputedStyle;
      window.egOriginalStandalone = Object.getOwnPropertyDescriptor(navigator, 'standalone');
      window.egOriginalViewport = Object.getOwnPropertyDescriptor(window, 'visualViewport');
      window.egViewport = Object.assign(new EventTarget(), {height: innerHeight, width: innerWidth, offsetTop: 0, offsetLeft: 0, pageTop: 0, pageLeft: 0, scale: 1});
      Object.defineProperty(window, 'visualViewport', {value: window.egViewport, configurable: true});
      window.egHost = document.createElement('div');
      window.egHost.id = 'eg-app';
      window.egHost.setAttribute('flt-embedding', 'custom-element');
      window.egHost.style.cssText = 'position:fixed;inset:0;pointer-events:none';
      document.body.appendChild(window.egHost);
      window.egInsets = {paddingTop: '59px', paddingRight: '0px', paddingBottom: '34px', paddingLeft: '0px'};
      Object.defineProperty(navigator, 'standalone', {value: true, configurable: true});
      window.getComputedStyle = function(node) {
        if (node.style.paddingTop === 'env(safe-area-inset-top)') return window.egInsets;
        return window.egOriginalStyle.apply(this, arguments);
      };
    ''');
  });

  tearDown(() {
    js('''
      window.getComputedStyle = window.egOriginalStyle;
      window.egHost.remove();
      if (window.egOriginalViewport) Object.defineProperty(window, 'visualViewport', window.egOriginalViewport);
      else delete window.visualViewport;
      if (window.egOriginalStandalone) {
        Object.defineProperty(navigator, 'standalone', window.egOriginalStandalone);
      } else {
        delete navigator.standalone;
      }
      delete window.egOriginalStyle;
      delete window.egOriginalStandalone;
      delete window.egInsets;
      delete window.egHost;
      delete window.egViewport;
      delete window.egOriginalViewport;
    ''');
  });

  test(
    'paint probe is reversible, installed-only, and does not resize the host',
    () {
      final before = WebStandalone.viewportReport();
      WebStandalone.setPaintProbe(true);
      final during = WebStandalone.viewportReport();
      expect(during, contains('Paint probe: on'));
      expect(
        during
            .split('\n')
            .firstWhere((line) => line.startsWith('Host client:')),
        before
            .split('\n')
            .firstWhere((line) => line.startsWith('Host client:')),
      );
      WebStandalone.setPaintProbe(false);
      expect(WebStandalone.viewportReport(), contains('Paint probe: off'));
      js(
        "Object.defineProperty(navigator, 'standalone', {value: false, configurable: true});",
      );
      WebStandalone.setPaintProbe(true);
      expect(WebStandalone.viewportReport(), contains('Paint probe: off'));
    },
  );

  test('screen report distinguishes a shortened host from its viewport', () {
    js("window.egHost.style.cssText = 'position:fixed;top:10px;height:500px';");
    final report = WebStandalone.viewportReport();
    expect(report, contains('Installed: true'));
    expect(report, contains('#eg-app: y=10..510, h=500'));
    expect(report, contains('Safe top/bottom: 59 / 34'));
    js('window.egHost.style.height = "600px";');
    expect(
      WebStandalone.viewportReport(),
      contains('#eg-app: y=10..610, h=600'),
    );
  });

  testWidgets('system insets protect controls without shrinking backgrounds', (
    tester,
  ) async {
    late MediaQueryData measured;
    const background = Key('background');
    const content = Key('content');
    Future<void> mount({double keyboard = 0}) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: WebStandaloneInsets(
            child: Builder(
              builder: (context) {
                measured = MediaQuery.of(context);
                return const Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(key: background, color: Colors.black),
                    ),
                    SafeArea(child: SizedBox.expand(key: content)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await mount();
    expect(measured.padding, const EdgeInsets.only(top: 59, bottom: 34));
    expect(tester.getTopLeft(find.byKey(background)), Offset.zero);
    expect(
      tester.getSize(find.byKey(background)),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
    expect(tester.getTopLeft(find.byKey(content)).dy, 59);
    expect(
      tester.getBottomRight(find.byKey(background)).dy -
          tester.getBottomRight(find.byKey(content)).dy,
      34,
    );

    await mount(keyboard: 300);
    expect(measured.padding.bottom, 0);
    expect(measured.viewPadding.bottom, 34);

    js(
      "window.egInsets = {paddingTop: '0px', paddingRight: '44px', paddingBottom: '21px', paddingLeft: '44px'}; window.dispatchEvent(new Event('resize'));",
    );
    await tester.pump();
    expect(measured.padding, const EdgeInsets.fromLTRB(44, 0, 44, 0));
    expect(measured.viewPadding, const EdgeInsets.fromLTRB(44, 0, 44, 21));
    await tester.pump(const Duration(milliseconds: 500));
  });

  test('browser tabs ignore system overlaps and bad measurements are rejected', () {
    js(
      "Object.defineProperty(navigator, 'standalone', {value: false, configurable: true});",
    );
    expect(WebStandalone.safeAreaPadding(), EdgeInsets.zero);
    js(
      "Object.defineProperty(navigator, 'standalone', {value: true, configurable: true}); window.egInsets = {paddingTop: 'NaNpx', paddingRight: '-1px', paddingBottom: '200px', paddingLeft: '44px'};",
    );
    expect(WebStandalone.safeAreaPadding(), const EdgeInsets.only(left: 44));
  });

  testWidgets(
    'focused Flutter field and bottom action clear the keyboard without clipping the canvas',
    (tester) async {
      const action = Key('action');
      late MediaQueryData measured;
      // Unregistering the stub alone still drops messages in web widget tests.
      // Let the engine create its real DOM text field for this regression.
      final environment = ui_web.TestEnvironment.instance;
      ui_web.TestEnvironment.setUp(
        ui_web.TestEnvironment(
          forceTestFonts: environment.forceTestFonts,
          disableFontFallbacks: environment.disableFontFallbacks,
          keepSemanticsDisabledOnUpdate:
              environment.keepSemanticsDisabledOnUpdate,
          defaultToTestUrlStrategy: environment.defaultToTestUrlStrategy,
        ),
      );
      addTearDown(() => ui_web.TestEnvironment.setUp(environment));
      tester.testTextInput.unregister();
      addTearDown(tester.testTextInput.register);
      await tester.pumpWidget(
        MaterialApp(
          home: WebStandaloneInsets(
            child: Builder(
              builder: (context) {
                measured = MediaQuery.of(context);
                return Scaffold(
                  body: SafeArea(
                    child: Column(
                      children: [
                        const TextField(),
                        const Spacer(),
                        ElevatedButton(
                          key: action,
                          onPressed: () {},
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final size = measured.size;
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        (_eval('document.activeElement.tagName'.toJS) as JSString).toDart,
        'INPUT',
        reason: 'The keyboard bridge needs the engine DOM field focused.',
      );
      expect(WebStandalone.keyboardInset(), 0);

      js(
        "window.egViewport.height = innerHeight - 300; window.egViewport.dispatchEvent(new Event('resize'));",
      );
      await tester.pump();
      expect(measured.size, size);
      expect(measured.viewInsets.bottom, 300);
      expect(measured.padding.bottom, 0);
      expect(
        tester.getBottomRight(find.byKey(action)).dy,
        lessThanOrEqualTo(size.height - 300),
      );
      expect(find.byType(TextField), findsOneWidget);

      js(
        "window.egViewport.height = innerHeight; window.egViewport.dispatchEvent(new Event('resize'));",
      );
      await tester.pump();
      expect(measured.viewInsets.bottom, 0);
      expect(measured.padding.bottom, 34);
      expect(
        tester.getBottomRight(find.byKey(action)).dy,
        greaterThan(size.height - 300),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}
