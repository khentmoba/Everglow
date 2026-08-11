import 'package:flutter/material.dart';import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/on_this_day_service.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// A dashboard card that surfaces spontaneous nostalgia from Gallery,
/// Cinema, and Chat — items that share today's calendar date from
/// previous years. Hidden entirely when nothing matches.
class OnThisDayCard extends StatefulWidget {
  const OnThisDayCard({super.key});

  @override
  State<OnThisDayCard> createState() => _OnThisDayCardState();
}

class _OnThisDayCardState extends State<OnThisDayCard>
    with SingleTickerProviderStateMixin {
  final OnThisDayService _service = OnThisDayService();
  List<OnThisDayMemory> _memories = [];
  bool _loading = true;
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _load();
  }

  Future<void> _load() async {
    final memories = await _service.getAllMemories();
    if (!mounted) return;
    setState(() {
      _memories = memories;
      _loading = false;
    });
    if (memories.isNotEmpty) {
      _staggerController.forward();
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_memories.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.blushGold.withValues(alpha: 0.08),
            AppTheme.deepRose.withValues(alpha: 0.06),
            AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.blushGold.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.blushGold.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // — Header —
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.blushGold.withValues(alpha: 0.2),
                        AppTheme.deepRose.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.blushGold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.blushGold,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'On This Day',
                        style: AppTypography.cormorantBold.copyWith(fontSize: 20, letterSpacing: 0.5, color: AppTheme.blushGold),
                      ),
                      Text(
                        '${_memories.length} ${_memories.length == 1 ? 'memory' : 'memories'} from the past',
                        style: AppTypography.outfitWhite.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.petalWhite.withValues(alpha: 0.55), letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // — Memory cards —
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _memories.length,
              itemBuilder: (context, index) {
                final delayMs = (index * 100).clamp(0, 600);
                final animation = CurvedAnimation(
                  parent: _staggerController,
                  curve: Interval(
                    (delayMs / 800).clamp(0.0, 1.0),
                    1.0,
                    curve: Curves.easeOutCubic,
                  ),
                );
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - animation.value)),
                      child: Opacity(
                        opacity: animation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _MemoryCard(
                      memory: _memories[index],
                      onTap: () => _onMemoryTap(_memories[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _onMemoryTap(OnThisDayMemory memory) {
    switch (memory.source) {
      case OnThisDaySource.gallery:
        context.push('/gallery');
        break;
      case OnThisDaySource.cinema:
        context.push('/cinema');
        break;
      case OnThisDaySource.chat:
        context.push('/chat');
        break;
    }
  }
}

class _MemoryCard extends StatefulWidget {
  final OnThisDayMemory memory;
  final VoidCallback? onTap;

  const _MemoryCard({required this.memory, this.onTap});

  @override
  State<_MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<_MemoryCard> {
  bool _hovered = false;
  bool _pressed = false;

  static const _tmdbImageBase = 'https://image.tmdb.org/t/p/w342';

  IconData get _sourceIcon {
    switch (widget.memory.source) {
      case OnThisDaySource.gallery:
        return Icons.photo_library_rounded;
      case OnThisDaySource.cinema:
        return Icons.local_movies_rounded;
      case OnThisDaySource.chat:
        return Icons.chat_bubble_rounded;
    }
  }

  Color get _sourceColor {
    switch (widget.memory.source) {
      case OnThisDaySource.gallery:
        return AppTheme.roseQuartz;
      case OnThisDaySource.cinema:
        return AppTheme.deepRose;
      case OnThisDaySource.chat:
        return AppTheme.softLavender;
    }
  }

  String get _resolvedPosterUrl {
    final url = widget.memory.posterUrl ?? '';
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$_tmdbImageBase$url';
  }

  @override
  Widget build(BuildContext context) {
    final yearsAgo = widget.memory.yearsAgo;
    final hasImage =
        (widget.memory.imageUrl != null && widget.memory.imageUrl!.isNotEmpty) ||
        (widget.memory.posterUrl != null && widget.memory.posterUrl!.isNotEmpty);
    final resolvedUrl = widget.memory.imageUrl ?? _resolvedPosterUrl;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 140,
          transform: Matrix4.identity()
            ..translate(0.0, _hovered ? -3.0 : 0.0)
            ..scale(_pressed ? 0.97 : (_hovered ? 1.03 : 1.0)),
          decoration: BoxDecoration(
            color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? AppTheme.blushGold.withValues(alpha: 0.5)
                  : AppTheme.blushGold.withValues(alpha: 0.15),
            ),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                  color: AppTheme.blushGold.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // — Visual area —
                SizedBox(
                  height: 82,
                  width: 140,
                  child: hasImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              resolvedUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _CardPlaceholder(icon: _sourceIcon, color: _sourceColor),
                            ),
                            // Scrim for readability
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.45),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : _CardPlaceholder(icon: _sourceIcon, color: _sourceColor),
                ),

                // — Text area —
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.memory.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppTheme.petalWhite, height: 1.2),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              _sourceIcon,
                              size: 10,
                              color: _sourceColor.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$yearsAgo ${yearsAgo == 1 ? 'year' : 'years'} ago',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitWhite.copyWith(fontSize: 9, fontWeight: FontWeight.w500, color: AppTheme.blushGold.withValues(alpha: 0.8), letterSpacing: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _CardPlaceholder({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.velvet,
            AppTheme.twilight,
            color.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: color.withValues(alpha: 0.6),
          size: 24,
        ),
      ),
    );
  }
}

