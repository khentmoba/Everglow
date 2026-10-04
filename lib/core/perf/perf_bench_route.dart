/// Deterministic performance bench, compiled in **only** for perf runs.
///
/// Built with `--dart-define=EG_PERF_BENCH=true`, so every production build
/// tree-shakes this file and its route away (the guard below is a compile-time
/// constant, so `if (kPerfBenchCompiledIn) ...perfBenchRoutes` is dead code
/// when the define is absent).
///
/// ## Why this exists
///
/// The frame meter publishes real `FrameTiming` numbers, but every real screen
/// is behind Firebase Auth and needs live Firestore data. A headless run
/// therefore has nothing to scroll — and a synthetic `flutter_test` tree
/// cannot produce web frame timings at all, because it never rasterises.
///
/// So this route composes the *real* shared widgets that actually cost frames
/// — `DashboardAmbience`, `ShimmerTitle`, `PulseHeart`, `EverglowMarquee`,
/// `DeferredSection`, `ShelfPosterCard` — over *fixed* content, so two builds
/// differ only by the code under test.
///
/// ## What it is honest about
///
/// This measures the **shared render layer**, which is where the fixes in
/// docs/PERF_NOTES.md live. It is not the real dashboard and does not
/// measure Firestore fan-out, auth or per-feature layout. Real-content screens
/// are verified on the phone (Creator Studio -> System -> frame meter), which
/// no headless rig can replace. See docs/perf-baseline.md.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/widgets/dashboard_motion.dart';
import '../../features/dashboard/presentation/widgets/deferred_section.dart';
import '../../shared/widgets/everglow/everglow_marquee.dart';
import '../../shared/widgets/shelf/shelf_poster_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// True only in builds made with `--dart-define=EG_PERF_BENCH=true`.
const bool kPerfBenchCompiledIn = bool.fromEnvironment('EG_PERF_BENCH');

/// Routes contributed to the app router when the bench is compiled in.
///
/// Not `const`: `GoRoute` has no const constructor. The guard that includes
/// this list is a compile-time constant, so a production build still drops
/// every route below along with this file's imports.
final List<RouteBase> perfBenchRoutes = <RouteBase>[
  GoRoute(
    path: '/perf-bench',
    builder: (context, state) => const PerfBenchScreen(scene: 'shelves'),
  ),
  GoRoute(
    path: '/perf-bench/grid',
    builder: (context, state) => const PerfBenchScreen(scene: 'grid'),
  ),
  // Same scene without the full-screen aurora painter, so its cost can be
  // measured instead of guessed at: /perf-bench/shelves?ambience=0.
  GoRoute(
    path: '/perf-bench/shelves-plain',
    builder: (context, state) => const PerfBenchScreen(
      scene: 'shelves',
      ambience: false,
    ),
  ),
];

/// The scenes this bench can render, so a run is always reproducible by name.
const List<String> perfBenchScenes = <String>['shelves', 'grid'];

/// Real photos shipped in the app bundle. Served over the perf build's own
/// origin, so they exercise the full `CachedNetworkImage` fetch + decode path
/// with zero third-party variance and no network egress.
const List<String> _benchPhotos = <String>[
  'birthday_pre_khent_1.jpg',
  'birthday_pre_khent_2.jpg',
  'birthday_pre_khent_3.jpg',
  'birthday_pre_khent_4.jpg',
  'birthday_pre_khent_5.jpg',
  'friends_bar_khent_1.jpg',
  'friends_bar_khent_2.jpg',
  'friends_bar_khent_3.jpg',
  'friends_bar_khent_4.jpg',
  'friends_bar_khent_5.jpg',
  'friends_bar_khent_6.jpg',
  'friends_bar_khent_7.jpg',
  'friends_bar_khent_8.jpg',
];

/// Absolute URL for a bundled photo.
///
/// Resolved from the site root, not with [Uri.resolve] against [Uri.base]: the
/// bench lives at `/perf-bench` *and* `/perf-bench/<scene>`, and a relative
/// resolve against a nested route yields `/perf-bench/assets/...`, which 404s.
/// That silently produced an imageless scene whose numbers looked fine — the
/// same class of bug as measuring the wrong screen, so the root is derived
/// explicitly and a deployment under a sub-path still works.
String _photoUrl(int index) {
  final name = _benchPhotos[index % _benchPhotos.length];
  final basePath = Uri.base.path;
  final cut = basePath.indexOf('/perf-bench');
  final prefix = cut >= 0 ? basePath.substring(0, cut) : basePath;
  return Uri.parse('${Uri.base.origin}$prefix/assets/assets/images/milestones/$name')
      .toString();
}

/// Deterministic stress scenes for headless measurement.
///
/// Content is fixed (counts, titles, image order) so that a before/after pair
/// only differs by the code under test. Anything non-deterministic — random
/// seeds, time-of-day art, network catalogues — would make the noise band
/// wider than the effects being measured.
class PerfBenchScreen extends StatefulWidget {
  const PerfBenchScreen({
    super.key,
    required this.scene,
    this.ambience = true,
  });

  final String scene;

  /// Draw the full-screen aurora painter. Off gives the A/B baseline for
  /// whatever that painter actually costs per frame.
  final bool ambience;

  @override
  State<PerfBenchScreen> createState() => _PerfBenchScreenState();
}

class _PerfBenchScreenState extends State<PerfBenchScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Stack(
        children: <Widget>[
          // The full-screen aurora/petal painter. Per docs/PERF_NOTES.md this
          // is the single largest raster cost on the dashboard, because web
          // keeps no rendered layers and repays every pixel each frame.
          if (widget.ambience) DashboardAmbience(scrollController: _scroll),
          CustomScrollView(
            controller: _scroll,
            slivers: <Widget>[
              SliverToBoxAdapter(child: _header()),
              if (widget.scene == 'grid')
                ..._gridSlivers()
              else
                ..._shelfSlivers(),
              const SliverToBoxAdapter(child: SizedBox(height: 600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 64, 16, 8),
      child: ShimmerTitle(
        child: PulseHeart(
          child: Text(
            'perf bench — ${widget.scene}',
            style: AppTypography.headlineSmall().copyWith(
              color: AppColors.petalWhite,
            ),
          ),
        ),
      ),
    );
  }

  /// Mirrors the dashboard's shape: many deferred sections, each a horizontal
  /// shelf of poster cards, with a drifting marquee row mixed in.
  List<Widget> _shelfSlivers() {
    final slivers = <Widget>[];
    for (var section = 0; section < 20; section++) {
      // Every fifth row is a drifting marquee instead of a poster shelf, so
      // the bench covers the ShaderMask edge-fade path that #440 made pause
      // during scroll alongside the poster path.
      if (section % 5 == 4) {
        slivers.add(
          const SliverToBoxAdapter(
            child: DeferredSection(
              placeholderHeight: 200,
              child: PerfBenchMarqueeRow(),
            ),
          ),
        );
        continue;
      }
      slivers.add(
        SliverToBoxAdapter(
          child: DeferredSection(
            placeholderHeight: 260,
            child: SizedBox(
              height: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: ShimmerTitle(
                      child: Text(
                        'Shelf $section',
                        style: AppTypography.titleMedium().copyWith(
                          color: AppColors.petalWhite,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _shelfRow(section),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _shelfRow(int section) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 14,
      itemBuilder: (context, i) {
        final index = section * 14 + i;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 130,
            child: ShelfPosterCard(
              imageUrl: _photoUrl(index),
              title: 'Title ${index % 97}',
              subtitle: '2026 · Bench',
              badge: i < 3 ? 'TOP ${i + 1}' : null,
            ),
          ),
        );
      },
    );
  }

  /// Dense vertical poster grid, the cinema/anime browse shape.
  List<Widget> _gridSlivers() {
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => ShelfPosterCard(
              imageUrl: _photoUrl(i),
              title: 'Grid ${i % 97}',
              subtitle: '2026',
            ),
            childCount: 120,
          ),
        ),
      ),
    ];
  }
}

/// A marquee row kept alongside the shelves so the bench also covers the
/// `ShaderMask` edge-fade path that #440 made pause during scroll.
class PerfBenchMarqueeRow extends StatelessWidget {
  const PerfBenchMarqueeRow({super.key});

  @override
  Widget build(BuildContext context) {
    return EverglowMarquee(
      shimmer: true,
      height: 180,
      children: <Widget>[
        for (var i = 0; i < 12; i++)
          Container(
            width: 130,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.deepRose.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
      ],
    );
  }
}