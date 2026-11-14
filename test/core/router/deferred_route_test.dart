import 'package:everglow/core/router/deferred_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DeferredRouteLoader.debugReset);

  Widget loader(String label, Future<void> Function() load) => MaterialApp(
    home: DeferredRouteLoader(
      label: label,
      loadLibrary: load,
      builder: () => const Text('screen'),
    ),
  );

  testWidgets('first visit waits for the chunk, a revisit paints at once', (
    tester,
  ) async {
    var loads = 0;
    Future<void> load() async => loads++;

    await tester.pumpWidget(loader('Anime', load));
    expect(find.text('Loading Anime…'), findsOneWidget);
    await tester.pump();
    expect(find.text('screen'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(loader('Anime', load));
    // No pump: the very first frame of the revisit is already the screen.
    expect(find.text('screen'), findsOneWidget);
    expect(find.text('Loading Anime…'), findsNothing);
    expect(loads, 1);
  });

  testWidgets('a warmed chunk opens on the first frame', (tester) async {
    await DeferredRouteLoader.warm('Books', () async {});
    expect(DeferredRouteLoader.isLoaded('Books'), isTrue);

    await tester.pumpWidget(
      loader('Books', () async => fail('warm chunk loaded again')),
    );
    expect(find.text('screen'), findsOneWidget);
  });

  testWidgets('a failed chunk is not remembered and can retry', (
    tester,
  ) async {
    var attempt = 0;
    Future<void> load() async {
      attempt++;
      if (attempt == 1) throw Exception('offline');
    }

    await DeferredRouteLoader.warm('Manga', load);
    expect(DeferredRouteLoader.isLoaded('Manga'), isFalse);

    await tester.pumpWidget(loader('Manga', load));
    await tester.pump();
    expect(find.text('screen'), findsOneWidget);
    expect(DeferredRouteLoader.isLoaded('Manga'), isTrue);
  });
}
