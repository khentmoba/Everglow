import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/features/dashboard/presentation/widgets/deferred_section.dart';
import 'package:everglow/shared/widgets/app_network_image.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';

Widget _buildShelfRow({required bool isolateCards}) {
  return SizedBox(
    height: 220,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 15,
      itemBuilder: (context, index) {
        final card = ShelfPosterCard(
          imageUrl: '',
          title: 'Movie $index',
          subtitle: '2026 · Demo',
          badge: index < 3 ? 'TOP ${index + 1}' : null,
        );
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 130,
            child: isolateCards ? RepaintBoundary(child: card) : card,
          ),
        );
      },
    ),
  );
}

Widget _buildScene({
  required ScrollController controller,
  required bool useOptimizedDeferred,
  required bool isolateCards,
  required Set<int> mountedTracker,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: CustomScrollView(
        controller: controller,
        slivers: [
          for (var i = 0; i < 20; i++)
            SliverToBoxAdapter(
              child: useOptimizedDeferred
                  ? DeferredSection(
                      placeholderHeight: 250,
                      child: _TrackedSection(
                        id: i,
                        tracker: mountedTracker,
                        child: _buildShelfRow(isolateCards: isolateCards),
                      ),
                    )
                  : _TrackedSection(
                      id: i,
                      tracker: mountedTracker,
                      child: _buildShelfRow(isolateCards: isolateCards),
                    ),
            ),
        ],
      ),
    ),
  );
}

class _TrackedSection extends StatefulWidget {
  final int id;
  final Set<int> tracker;
  final Widget child;

  const _TrackedSection({
    required this.id,
    required this.tracker,
    required this.child,
  });

  @override
  State<_TrackedSection> createState() => _TrackedSectionState();
}

class _TrackedSectionState extends State<_TrackedSection> {
  @override
  void initState() {
    super.initState();
    widget.tracker.add(widget.id);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  group('Ultra-Performance Scroll & Memory Benchmarks', () {
    testWidgets('Frame-1 mounts stay lazy and scrolling still works', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final baselineMounted = <int>{};
      final baselineController = ScrollController();
      addTearDown(baselineController.dispose);

      await tester.pumpWidget(
        _buildScene(
          controller: baselineController,
          useOptimizedDeferred: false,
          isolateCards: false,
          mountedTracker: baselineMounted,
        ),
      );
      await tester.pump();
      final baselineInitialMountCount = baselineMounted.length;

      final optimizedMounted = <int>{};
      final optimizedController = ScrollController();
      addTearDown(optimizedController.dispose);

      await tester.pumpWidget(
        _buildScene(
          controller: optimizedController,
          useOptimizedDeferred: true,
          isolateCards: true,
          mountedTracker: optimizedMounted,
        ),
      );
      await tester.pump();
      final optimizedInitialMountCount = optimizedMounted.length;

      expect(optimizedInitialMountCount, lessThanOrEqualTo(4));
      final mountReduction = (baselineInitialMountCount - optimizedInitialMountCount) / baselineInitialMountCount;
      expect(mountReduction, greaterThanOrEqualTo(0.80));

      optimizedController.jumpTo(1200.0);
      await tester.pump();
      optimizedController.jumpTo(2400.0);
      await tester.pump();
      expect(tester.takeException(), isNull);

      debugPrint('[PERF] Baseline Frame-1 Mounts: $baselineInitialMountCount');
      debugPrint('[PERF] Optimized Frame-1 Mounts: $optimizedInitialMountCount '
          '(${(mountReduction * 100).toStringAsFixed(1)}% reduction)');
    });

    test('decoded shelf memory is bounded using the shipped cacheWidth logic', () {
      const itemsPerSurface = 30;
      const bytesPerPixel = 4;

      const naturalWidth = 780;
      const naturalHeight = 1170;
      final naturalBytes = naturalWidth * naturalHeight * bytesPerPixel;

      int sizedBytesFor({
        int? declaredWidth,
        double? displayWidth,
        double? displayHeight,
      }) {
        final w = AppNetworkImage.resolveCacheWidth(
          declaredCacheWidth: declaredWidth,
          displayWidth: displayWidth,
        );
        final h = AppNetworkImage.resolveCacheHeight(
          declaredCacheHeight: null,
          displayHeight: displayHeight,
          explicitWidth: declaredWidth,
        );
        expect(w, isNotNull, reason: 'a sized decode must force a width');
        final usedWidth = w!;
        final height = h ?? (usedWidth * naturalHeight / naturalWidth).round();
        return usedWidth * height * bytesPerPixel;
      }

      final shelfCard = sizedBytesFor(displayWidth: 128, displayHeight: 186);
      final posterCard = sizedBytesFor(declaredWidth: 400);

      expect(
        AppNetworkImage.resolveCacheWidth(declaredCacheWidth: null, displayWidth: 128),
        256,
        reason: 'a 128px card should derive a 256px decode',
      );
      expect(
        AppNetworkImage.resolveCacheWidth(declaredCacheWidth: 400, displayWidth: 128),
        400,
        reason: 'an explicit cacheWidth must win over the derived one',
      );

      final surfaces = itemsPerSurface * 2;
      final rawTotal = naturalBytes * surfaces;
      final sizedTotal = (shelfCard + posterCard) * itemsPerSurface;
      final reduction = (rawTotal - sizedTotal) / rawTotal;

      debugPrint('[MEMORY] ShelfCard(128w) decode  : ${(shelfCard / 1048576).toStringAsFixed(3)} MB per image');
      debugPrint('[MEMORY] ShelfPosterCard(400w) decode: ${(posterCard / 1048576).toStringAsFixed(3)} MB per image');
      debugPrint('[MEMORY] natural decode          : ${(naturalBytes / 1048576).toStringAsFixed(3)} MB per image');
      debugPrint('[MEMORY] $surfaces images: ${(rawTotal / 1048576).toStringAsFixed(1)} MB -> ${(sizedTotal / 1048576).toStringAsFixed(1)} MB '
          '(${(reduction * 100).toStringAsFixed(1)}% smaller)');

      expect(reduction, greaterThan(0.80), reason: 'sized decodes should cut texture memory by >80%');
      expect(
        sizedTotal / 1048576,
        lessThan(40.0),
        reason: 'two rails of sized posters should stay well under 40MB of texture',
      );
    });
  });
}
