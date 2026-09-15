import 'package:flutter/material.dart';

import './katana_theme.dart';

/// Shimmer placeholders shaped like real Katana content, so tab
/// switches land on a soft pulse instead of a bare spinner.
class KatanaListSkeleton extends StatelessWidget {
  final int rows;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  const KatanaListSkeleton({
    super.key,
    this.rows = 6,
    this.padding = const EdgeInsets.all(16),
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      child: ListView(
        physics: physics,
        padding: padding,
        children: [
          for (int i = 0; i < rows; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _ListRow(),
            ),
        ],
      ),
    );
  }
}

/// Placeholder for the Genres page: heading lines plus a grid of
/// genre-shaped cards.
class KatanaGenreGridSkeleton extends StatelessWidget {
  final int cards;

  const KatanaGenreGridSkeleton({super.key, this.cards = 8});

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Block(width: 140, height: 22),
          const SizedBox(height: 6),
          const _Block(width: 90, height: 12),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 330,
              childAspectRatio: 2.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: cards,
            itemBuilder: (_, _) => const KatanaCard(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Block(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  _Block(width: 150, height: 10),
                  SizedBox(height: 6),
                  _Block(width: 110, height: 10),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// One cover-plus-lines row, shaped like a [KatanaCard] list item.
class _ListRow extends StatelessWidget {
  const _ListRow();

  @override
  Widget build(BuildContext context) {
    return const KatanaCard(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          _Block(width: 80, height: 110, radius: 6),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Block(width: double.infinity, height: 14),
                SizedBox(height: 10),
                _Block(width: 180, height: 10),
                SizedBox(height: 10),
                _Block(width: 120, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One grey bar or cover block.
class _Block extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const _Block({this.width, this.height, this.radius = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: KatanaColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Fades [child] between full and half opacity on a loop, so
/// skeletons shimmer gently while content loads.
class _Pulse extends StatefulWidget {
  final Widget child;

  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) =>
          Opacity(opacity: 0.45 + 0.55 * _controller.value, child: child),
      child: widget.child,
    );
  }
}
