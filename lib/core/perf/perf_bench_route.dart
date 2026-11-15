library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/widgets/dashboard_motion.dart';
import '../../features/dashboard/presentation/widgets/deferred_section.dart';
import '../../shared/widgets/everglow/everglow_marquee.dart';
import '../../shared/widgets/shelf/shelf_poster_card.dart';
import 'perf_probe.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

const bool kPerfBenchCompiledIn = bool.fromEnvironment('EG_PERF_BENCH');

final List<RouteBase> perfBenchRoutes = <RouteBase>[
  GoRoute(
    path: '/perf-bench',
    builder: (context, state) => const PerfBenchScreen(scene: 'shelves'),
  ),
  GoRoute(
    path: '/perf-bench/grid',
    builder: (context, state) => const PerfBenchScreen(scene: 'grid'),
  ),
  GoRoute(
    path: '/perf-bench/shelves-plain',
    builder: (context, state) =>
        const PerfBenchScreen(scene: 'shelves', ambience: false),
  ),
];

const List<String> perfBenchScenes = <String>['shelves', 'grid'];

const List<String> _benchPhotos = <String>[
  'poster-1.jpg',
  'poster-2.jpg',
  'poster-3.jpg',
  'poster-4.jpg',
];

String _photoUrl(int index) {
  final name = _benchPhotos[index % _benchPhotos.length];
  final basePath = Uri.base.path;
  final cut = basePath.indexOf('/perf-bench');
  final prefix = cut >= 0 ? basePath.substring(0, cut) : basePath;
  return Uri.parse('${Uri.base.origin}$prefix/perf-fixtures/$name').toString();
}

class PerfBenchScreen extends StatefulWidget {
  const PerfBenchScreen({super.key, required this.scene, this.ambience = true});

  final String scene;

  final bool ambience;

  @override
  State<PerfBenchScreen> createState() => _PerfBenchScreenState();
}

class _PerfBenchScreenState extends State<PerfBenchScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    registerBenchScroll(
      () => <String, Object>{
        'scene': widget.scene == 'shelves' && !widget.ambience
            ? 'shelves-plain'
            : widget.scene,
        'offset': _scroll.hasClients ? _scroll.offset : 0.0,
        'maxScrollExtent': _scroll.hasClients
            ? _scroll.position.maxScrollExtent
            : 0.0,
      },
    );
  }

  @override
  void dispose() {
    registerBenchScroll(null);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Stack(
        children: <Widget>[
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

  List<Widget> _shelfSlivers() {
    final slivers = <Widget>[];
    for (var section = 0; section < 20; section++) {
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
                  Expanded(child: _shelfRow(section)),
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
