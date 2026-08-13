import 'package:flutter/material.dart';

import '../../../data/models/media_item.dart';

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
  bool _paused = false;

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

    return MouseRegion(
      onEnter: (_) => setState(() => _paused = true),
      onExit: (_) => setState(() => _paused = false),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: AnimeXTokens.surface,
          border: Border(
            top: BorderSide(color: AnimeXTokens.border),
            bottom: BorderSide(color: AnimeXTokens.border),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: _paused
            ? _track(context)
            : AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(-_ctrl.value * _trackWidth(context), 0),
                    child: _track(context),
                  );
                },
              ),
      ),
    );
  }

  double _trackWidth(BuildContext context) {
    // Approximate the rendered width of a single track copy.
    final perItem = widget.items.length * 210.0 + 120;
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [once, once],
    );
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
                decoration: const BoxDecoration(
                  color: AnimeXTokens.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dmSansStyle(
                    size: 12.5,
                    color: AnimeXTokens.textSecondary,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'EP ${item.currentEpisode ?? 1}',
                style: dmSansStyle(
                  size: 11,
                  color: AnimeXTokens.accentWarm,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
