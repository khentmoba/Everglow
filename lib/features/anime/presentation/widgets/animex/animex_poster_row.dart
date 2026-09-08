import 'package:flutter/material.dart';

import '../../../../cinema/data/models/media_item.dart';

import 'animex_poster_card.dart';
import 'animex_tokens.dart';

/// Horizontal scrolling row of poster cards with hidden scrollbars,
/// hover-reveal arrow buttons (desktop) and soft edge fades.
class AnimeXPosterRow extends StatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem) onTap;
  final double cardWidth;
  final Map<int, double>? progressByIndex;
  final Map<int, String>? episodeLabels;

  const AnimeXPosterRow({
    super.key,
    required this.items,
    required this.onTap,
    this.cardWidth = AnimeXTokens.rowPosterWidthDesktop,
    this.progressByIndex,
    this.episodeLabels,
  });

  @override
  State<AnimeXPosterRow> createState() => _AnimeXPosterRowState();
}

class _AnimeXPosterRowState extends State<AnimeXPosterRow> {
  final ScrollController _ctrl = ScrollController();
  bool _hover = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _scrollBy(double dx) {
    if (!_ctrl.hasClients) return;
    final target = (_ctrl.offset + dx).clamp(
      0.0,
      _ctrl.position.maxScrollExtent,
    );
    _ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final page = widget.cardWidth * 3 + 32;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SizedBox(
        height: widget.cardWidth * 1.5 + 56,
        child: Stack(
          children: [
            ListView.separated(
              controller: _ctrl,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final item = widget.items[i];
                return AnimeXPosterCard(
                  item: item,
                  width: widget.cardWidth,
                  onTap: () => widget.onTap(item),
                  progress: widget.progressByIndex?[i],
                  episodeLabel: widget.episodeLabels?[i],
                );
              },
            ),
            // Soft fades so cards slide in from under the edges.
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _EdgeFade(left: true),
            ),
            const Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _EdgeFade(left: false),
            ),
            Positioned(
              left: 8,
              top: 0,
              bottom: 56,
              child: Center(
                child: _RowArrow(
                  visible: _hover,
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _scrollBy(-page),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 56,
              child: Center(
                child: _RowArrow(
                  visible: _hover,
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _scrollBy(page),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  final bool left;

  const _EdgeFade({required this.left});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [AnimeXTokens.bg, AnimeXTokens.bg.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _RowArrow extends StatelessWidget {
  final bool visible;
  final IconData icon;
  final VoidCallback onTap;

  const _RowArrow({
    required this.visible,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xCC14141C),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
