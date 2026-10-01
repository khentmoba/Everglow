@TestOn('browser')
library;

import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:everglow/features/ai/presentation/widgets/canvas_html_view_web.dart';
import 'package:everglow/features/jukebox/presentation/widgets/spotify_embed_view_web.dart';

// Counts custom factory registrations (must stay zero) and supplies dummy
// roots so fromTagName callbacks run without loading third parties.
class _Registry extends ui_web.PlatformViewRegistry {
  int customFactories = 0;
  @override
  bool registerViewFactory(
    String type,
    Function factory, {
    bool isVisible = true,
  }) {
    customFactories++;
    return super.registerViewFactory(type, factory, isVisible: isVisible);
  }

  @override
  Object getViewById(int id) => web.HTMLDivElement();
}

void main() {
  late _Registry registry;
  setUp(() {
    registry = _Registry();
    ui_web.debugOverridePlatformViewRegistry(registry);
  });
  tearDown(() => ui_web.debugOverridePlatformViewRegistry(null));

  testWidgets('skipping tracks reuses one frame and releases it on exit', (
    tester,
  ) async {
    Widget build(String track) =>
        MaterialApp(home: SpotifyEmbedView(trackId: track));
    await tester.pumpWidget(build('trackAAA'));
    final state = tester.state(find.byType(SpotifyEmbedView)) as dynamic;
    final frame = state.debugIframe as web.HTMLIFrameElement;
    expect(frame.src, contains('/embed/track/trackAAA'));

    // Same slot, new track: the stored frame reloads instead of mounting
    // a second embed with its own registration.
    await tester.pumpWidget(build('trackBBB'));
    expect(state.debugIframe, same(frame));
    expect(frame.src, contains('/embed/track/trackBBB'));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(frame.src, 'about:blank');
    expect(frame.parentNode, isNull);
    expect(registry.customFactories, 0);
  });

  testWidgets('canvas answers update in place and release on exit', (
    tester,
  ) async {
    Widget build(String html) => MaterialApp(home: CanvasHtmlView(html: html));
    await tester.pumpWidget(build('<h1>demo one</h1>'));
    final state = tester.state(find.byType(CanvasHtmlView)) as dynamic;
    final frame = state.debugIframe as web.HTMLIFrameElement;
    expect(frame.getAttribute('srcdoc'), contains('demo one'));
    expect(frame.getAttribute('sandbox'), contains('allow-scripts'));

    await tester.pumpWidget(build('<h1>demo two</h1>'));
    expect(state.debugIframe, same(frame));
    expect(frame.getAttribute('srcdoc'), contains('demo two'));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(frame.src, 'about:blank');
    expect(frame.getAttribute('srcdoc'), isNull);
    expect(frame.parentNode, isNull);
    expect(registry.customFactories, 0);
  });
}
