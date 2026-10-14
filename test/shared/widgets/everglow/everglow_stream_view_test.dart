import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/shared/widgets/everglow/everglow_error_state.dart';
import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';
import 'package:everglow/shared/widgets/everglow/everglow_stream_view.dart';
import 'package:everglow/core/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  for (final width in [430.0, 810.0]) {
    testWidgets(
      'temporary failure keeps the mounted list and scroll at $width px',
      (tester) async {
        tester.view.physicalSize = Size(width, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const proofDir = String.fromEnvironment('EG_SLOW_PROOF_DIR');
        if (proofDir.isNotEmpty) {
          for (final font in {
            'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
            'Outfit': 'assets/google_fonts/Outfit-Medium.ttf',
            'Cormorant Garamond':
                'assets/google_fonts/CormorantGaramond-Bold.ttf',
          }.entries) {
            final loader = FontLoader(font.key)
              ..addFont(rootBundle.load(font.value));
            await tester.runAsync(loader.load);
          }
        }
        final controller = StreamController<List<String>>();
        final scroll = ScrollController();
        addTearDown(controller.close);
        addTearDown(scroll.dispose);
        final boundary = GlobalKey();
        var retries = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.gamifiedTheme,
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                appBar: AppBar(title: const Text('Demo saved entries')),
                body: EverglowStreamView<List<String>>(
                  stream: controller.stream,
                  onRetry: () => retries++,
                  builder: (_, items) => ListView.builder(
                    controller: scroll,
                    itemExtent: 88,
                    itemCount: items.length,
                    itemBuilder: (_, index) => ListTile(
                      title: Text(items[index]),
                      subtitle: const Text(
                        'These demo words stay here while the connection recovers.',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        controller.add([for (var i = 0; i < 30; i++) 'Demo memory ${i + 1}']);
        await tester.pump();
        await tester.pump();
        scroll.jumpTo(300);
        await tester.pump();
        final before = tester.state<ScrollableState>(find.byType(Scrollable));
        controller.addError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );
        await tester.pump();
        await tester.pump();
        expect(
          tester.state<ScrollableState>(find.byType(Scrollable)),
          same(before),
        );
        expect(scroll.offset, 300);
        expect(find.text('Could not refresh · Retry'), findsOneWidget);
        await tester.tap(find.text('Could not refresh · Retry'));
        expect(retries, 1);
        await tester.pumpAndSettle();
        if (proofDir.isNotEmpty) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$proofDir/live-list-network-error-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('a null update removes the previously loaded document', (
    tester,
  ) async {
    final controller = StreamController<String?>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      _wrap(
        EverglowStreamView<String?>(
          stream: controller.stream,
          builder: (_, value) => Text(value!),
        ),
      ),
    );
    controller.add('old document');
    await tester.pump();
    controller.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('old document'), findsNothing);
  });
  testWidgets('parent rebuilds keep one subscription and loaded rows', (
    tester,
  ) async {
    var listens = 0;
    var cancels = 0;
    final controller = StreamController<List<String>>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    addTearDown(controller.close);
    Widget view() => _wrap(
      EverglowStreamView<List<String>>(
        stream: controller.stream,
        builder: (_, items) => Text(items.single),
      ),
    );
    await tester.pumpWidget(view());
    controller.add(['saved row']);
    await tester.pump();
    await tester.pumpWidget(view());
    await tester.pump();
    expect(listens, 1);
    expect(cancels, 0);
    expect(find.text('saved row'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(cancels, 1);
  });

  testWidgets(
    'temporary failure retains rows but permission denial removes them',
    (tester) async {
      final controller = StreamController<List<String>>();
      addTearDown(controller.close);
      await tester.pumpWidget(
        _wrap(
          EverglowStreamView<List<String>>(
            stream: controller.stream,
            builder: (_, items) => Text(items.single),
          ),
        ),
      );
      controller.add(['saved row']);
      await tester.pump();
      controller.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('saved row'), findsOneWidget);
      controller.add(['updated row']);
      await tester.pump();
      await tester.pump();
      expect(find.text('updated row'), findsOneWidget);
      controller.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('updated row'), findsNothing);
      expect(find.byType(EverglowErrorState), findsOneWidget);
    },
  );

  testWidgets(
    'changing source discards previous rows and attaches the new stream',
    (tester) async {
      final first = StreamController<List<String>>();
      final second = StreamController<List<String>>();
      addTearDown(first.close);
      addTearDown(second.close);
      Widget view(Stream<List<String>> stream) => _wrap(
        EverglowStreamView<List<String>>(
          stream: stream,
          builder: (_, items) => Text(items.single),
        ),
      );
      await tester.pumpWidget(view(first.stream));
      first.add(['old profile']);
      await tester.pump();
      await tester.pumpWidget(view(second.stream));
      expect(find.text('old profile'), findsNothing);
      second.add(['new profile']);
      await tester.pump();
      expect(find.text('new profile'), findsOneWidget);
    },
  );

  testWidgets('shows loading then data', (tester) async {
    final controller = StreamController<List<String>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _wrap(
        EverglowStreamView<List<String>>(
          stream: controller.stream,
          builder: (context, items) =>
              ListView(children: [for (final i in items) Text(i)]),
        ),
      ),
    );

    expect(find.byType(EverglowLoadingState), findsOneWidget);

    controller.add(['a', 'b']);
    await tester.pump();

    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('shows empty view when isEmpty matches', (tester) async {
    final controller = StreamController<List<String>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _wrap(
        EverglowStreamView<List<String>>(
          stream: controller.stream,
          isEmpty: (items) => items.isEmpty,
          emptyView: const Text('nothing here'),
          builder: (context, items) => Text('${items.length} items'),
        ),
      ),
    );

    controller.add([]);
    await tester.pump();

    expect(find.text('nothing here'), findsOneWidget);
    expect(find.text('0 items'), findsNothing);
  });

  testWidgets('shows error card on stream error', (tester) async {
    final controller = StreamController<List<String>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _wrap(
        EverglowStreamView<List<String>>(
          stream: controller.stream,
          errorMessage: 'Could not load things',
          builder: (context, items) => Text('${items.length} items'),
        ),
      ),
    );

    controller.addError(Exception('boom'));
    await tester.pump();

    expect(find.byType(EverglowErrorState), findsOneWidget);
    expect(find.textContaining('Could not load things'), findsOneWidget);
  });
}
