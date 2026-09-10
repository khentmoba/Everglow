import 'package:flutter/material.dart';

import '../../../../cinema/data/models/media_item.dart';

import 'animex_tokens.dart';

/// Scrolling marquee of "Airing Today" items, pausing on hover.
class AnimeXTicker extends StatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem)? onTap;

  const AnimeXTicker({super.key, required this.items, this.onTap});

  @override
  State<AnimeXTicker> createState() => _AnimeXTickerState();
}

class _AnimeXTickerState extends State<AnimeXTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return MouseRegion(
      onEnter: (_) => _ctrl.stop(),
      onExit: (_) => _ctrl.repeat(),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AnimeXTokens.surface.withValues(alpha: 0.9),
              AnimeXTokens.bg,
            ],
          ),
          border: const Border(
            bottom: BorderSide(color: AnimeXTokens.border),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            // Fixed "Airing Today" label pinned to the left edge.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AnimeXTokens.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AnimeXTokens.success,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    narrow ? 'AIRING' : 'AIRING TODAY',
                    style: dmSansStyle(
                      size: 11,
                      color: AnimeXTokens.textPrimary,
                      weight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            // Scrolling marquee track with edge fades via ShaderMask.
            Expanded(
              child: ClipRect(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    if (bounds.width <= 48) {
                      return const LinearGradient(
                        colors: [Colors.white, Colors.white],
                      ).createShader(bounds);
                    }
                    final leftStop = (24.0 / bounds.width).clamp(0.0, 0.2);
                    final rightStop =
                        ((bounds.width - 32.0) / bounds.width).clamp(0.8, 1.0);
                    return LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: const [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0.0, leftStop, rightStop, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, _) {
                        return Transform.translate(
                          offset: Offset(
                            -_ctrl.value * _trackWidth(context),
                            0,
                          ),
                          child: _track(context),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _trackWidth(BuildContext context) {
    // Approximate the rendered width of a single track copy.
    final perItem = widget.items.length * 230.0 + 120;
    return perItem;
  }

  Widget _track(BuildContext context) {
    final once = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 24),
        for (final item in widget.items) _tickerItem(context, item),
      ],
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [once, once]);
  }

  Widget _tickerItem(BuildContext context, MediaItem item) {
    return GestureDetector(
      onTap: () => widget.onTap?.call(item),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AnimeXTokens.accentWarm.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dmSansStyle(
                    size: 12.5,
                    color: AnimeXTokens.textSecondary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AnimeXTokens.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(
                    AnimeXTokens.radiusSm,
                  ),
                  border: Border.all(
                    color: AnimeXTokens.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'EP ${item.currentEpisode ?? 1}',
                  style: dmSansStyle(
                    size: 10.5,
                    color: AnimeXTokens.accentWarm,
                    weight: FontWeight.w800,
                    letterSpacing: 0.04,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
