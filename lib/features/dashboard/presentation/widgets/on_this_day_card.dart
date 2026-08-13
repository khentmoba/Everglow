import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/on_this_day_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import 'feature_section.dart';

/// Dashboard card surfacing spontaneous nostalgia from Gallery, Cinema,
/// and Chat. Hidden entirely when nothing matches.
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FeatureSection(
        icon: Icons.history_rounded,
        hue: AppColors.blushGold,
        title: 'On This Day',
        subtitle:
            '${_memories.length} ${_memories.length == 1 ? 'memory' : 'memories'} from the past',
        trailing: const SectionChevron(),
        child: SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
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
                    child: Opacity(opacity: animation.value, child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _MemoryCard(
                    memory: _memories[index],
                    onTap: () => _onMemoryTap(_memories[index]),
                  ),
                ),
              );
            },
          ),
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
        context.push('/sanctuary');
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
        return AppColors.roseQuartz;
      case OnThisDaySource.cinema:
        return AppColors.deepRose;
      case OnThisDaySource.chat:
        return AppColors.softLavender;
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
        (widget.memory.imageUrl != null &&
            widget.memory.imageUrl!.isNotEmpty) ||
        (widget.memory.posterUrl != null &&
            widget.memory.posterUrl!.isNotEmpty);
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
          width: 150,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -4.0 : 0.0, 0.0, 1.0)
            ..scaleByDouble(
              _pressed ? 0.96 : (_hovered ? 1.04 : 1.0),
              _pressed ? 0.96 : (_hovered ? 1.04 : 1.0),
              _pressed ? 0.96 : (_hovered ? 1.04 : 1.0),
              1.0,
            ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.moonlight.withValues(alpha: 0.16),
                AppColors.inkDeep.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: _hovered
                  ? AppColors.blushGold.withValues(alpha: 0.55)
                  : AppColors.blushGold.withValues(alpha: 0.18),
            ),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                  color: AppColors.blushGold.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.radiusLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 86,
                  width: 150,
                  child: hasImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              resolvedUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _CardPlaceholder(
                                icon: _sourceIcon,
                                color: _sourceColor,
                              ),
                            ),
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
                      : _CardPlaceholder(
                          icon: _sourceIcon,
                          color: _sourceColor,
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.memory.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 11,
                            color: AppColors.petalWhite,
                            height: 1.2,
                          ),
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
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.blushGold.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
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
            AppColors.velvet,
            AppColors.twilight,
            color.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, color: color.withValues(alpha: 0.6), size: 24),
      ),
    );
  }
}
