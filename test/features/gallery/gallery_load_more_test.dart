import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/features/gallery/data/services/gallery_service.dart';
import 'package:everglow/features/gallery/domain/models/memory_photo.dart';
import 'package:everglow/features/gallery/presentation/screens/gallery_screen.dart';

class _Gallery extends GalleryService {
  final limits = <int>[];
  var mapFetches = 0;
  var weekFetches = 0;
  @override
  Future<List<MemoryPhoto>> getPhotosWithLocationStream() async {
    mapFetches++;
    return [];
  }

  @override
  Future<List<MemoryPhoto>> getPhotosFromThisWeek() async {
    weekFetches++;
    return [];
  }

  @override
  Stream<List<MemoryPhoto>> getPhotosStream({int limit = 40}) {
    limits.add(limit);
    return Stream.value(
      [
        for (var i = 0; i < 81; i++)
          MemoryPhoto(
            id: '$i',
            imageUrl: '',
            caption: 'Demo photo $i',
            uploadedBy: 'demo',
            uploadedAt: DateTime(2026, 2),
          ),
      ].take(limit).toList(),
    );
  }
}

void main() {
  testWidgets(
    'gallery opens another bounded page when Clair taps Load older photos',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gallery = _Gallery();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => GalleryScreen(service: gallery),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Load older photos'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(gallery.limits, [40]);
      await tester.tap(find.text('Load older photos'));
      await tester.pumpAndSettle();
      expect(gallery.limits, [40, 80]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('tab changes reuse the grid query and map request', (
    tester,
  ) async {
    final gallery = _Gallery();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => GalleryScreen(service: gallery),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(gallery.limits, [40]);
    expect(gallery.mapFetches, 1);
    expect(tester.takeException(), isNull);
  });
}
