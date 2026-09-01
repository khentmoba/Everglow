import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/milestone.dart';
import '../../data/services/milestone_service.dart';
import 'memory_detail_view.dart';
import '../../../../core/theme/app_typography.dart';

/// A scroll-driven horizontal timeline visualization of relationship milestones.
class RelationshipTimeline extends StatefulWidget {
  const RelationshipTimeline({super.key});

  @override
  State<RelationshipTimeline> createState() => _RelationshipTimelineState();
}

class _RelationshipTimelineState extends State<RelationshipTimeline> {
  final MilestoneService _milestoneService = MilestoneService();
  late ScrollController _scrollController;
  bool _showGallery = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday(List<Milestone> milestones) {
    if (milestones.isEmpty || !_scrollController.hasClients) return;
    final now = DateTime.now();

    // Find the index closest to today
    int closestIdx = 0;
    Duration minDiff = const Duration(days: 999999);
    for (int i = 0; i < milestones.length; i++) {
      final diff = milestones[i].date.difference(now).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = i;
      }
    }

    // Each node is ~120px wide, center it
    final targetOffset = (closestIdx * 120.0) - 200;
    _scrollController.animateTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section header with toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Divider(
                  color: AppColors.blushGold.withValues(alpha: 0.15),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  'OUR STORY',
                  style: AppTypography.cormorantBlack.copyWith(
                    fontSize: 20,
                    letterSpacing: 2.0,
                    shadows: [
                      BoxShadow(
                        color: AppColors.deepRose.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: AppColors.blushGold.withValues(alpha: 0.15),
                  thickness: 1,
                ),
              ),
            ],
          ),
        ),

        // View toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildToggleChip(
                'Timeline',
                !_showGallery,
                () => setState(() => _showGallery = false),
              ),
              const SizedBox(width: 8),
              _buildToggleChip(
                'Gallery',
                _showGallery,
                () => setState(() => _showGallery = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Content
        StreamBuilder<List<Milestone>>(
          stream: _milestoneService.milestones,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState();
            }

            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            final milestones = snapshot.data ?? [];
            if (milestones.isEmpty) {
              return const SizedBox.shrink();
            }

            // Scroll to today on first load
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToToday(milestones);
            });

            if (_showGallery) {
              return _GalleryView(milestones: milestones);
            }

            return _TimelineAxis(
              milestones: milestones,
              scrollController: _scrollController,
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildToggleChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'View as $label',
        toggled: isSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.deepRose.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.blushGold
                  : AppColors.blushGold.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppColors.blushGold
                  : AppColors.petalWhite.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 32,
            color: AppColors.roseQuartz.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Could not load timeline',
            style: AppTypography.outfitWhite.copyWith(
              color: AppColors.roseQuartz.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.deepRose.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading memories...',
            style: AppTypography.outfitWhite.copyWith(
              color: AppColors.roseQuartz.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// The horizontal scroll timeline axis with milestone nodes.
class _TimelineAxis extends StatelessWidget {
  final List<Milestone> milestones;
  final ScrollController scrollController;

  const _TimelineAxis({
    required this.milestones,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: CustomPaint(
          size: Size(milestones.length * 120.0, 200),
          painter: _TimelinePainter(
            milestones: milestones,
            today: DateTime.now(),
          ),
          child: Row(
            children: milestones.asMap().entries.map((entry) {
              final idx = entry.key;
              final milestone = entry.value;
              return _TimelineNode(
                milestone: milestone,
                isFirst: idx == 0,
                isLast: idx == milestones.length - 1,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Custom painter drawing the timeline line with year markers.
class _TimelinePainter extends CustomPainter {
  final List<Milestone> milestones;
  final DateTime today;

  _TimelinePainter({required this.milestones, required this.today});

  @override
  void paint(Canvas canvas, Size size) {
    final lineY = size.height * 0.6;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Timeline line gradient
    final linePath = Path();
    linePath.moveTo(60, lineY);
    linePath.lineTo(size.width - 60, lineY);

    paint
      ..shader = LinearGradient(
        colors: [
          AppColors.deepRose.withValues(alpha: 0.3),
          AppColors.blushGold.withValues(alpha: 0.6),
          AppColors.deepRose.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, lineY - 2, size.width, 4))
      ..strokeWidth = 2.5;
    canvas.drawPath(linePath, paint);

    // Year markers
    paint
      ..shader = null
      ..strokeWidth = 1;

    int? lastYear;
    for (int i = 0; i < milestones.length; i++) {
      final year = milestones[i].date.year;
      if (year != lastYear) {
        final x = 60.0 + (i * 120.0);
        // Year tick
        paint.color = AppColors.blushGold.withValues(alpha: 0.3);
        canvas.drawLine(Offset(x, lineY - 8), Offset(x, lineY + 8), paint);

        // Year label
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$year',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 10,
              color: AppColors.blushGold.withValues(alpha: 0.5),
            ),
          ),
        )..layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, lineY + 14),
        );
        lastYear = year;
      }
    }

    // "Today" indicator
    // Find closest milestone to today and draw a pulsing dot
    int closestIdx = 0;
    Duration minDiff = const Duration(days: 999999);
    for (int i = 0; i < milestones.length; i++) {
      final diff = milestones[i].date.difference(today).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = i;
      }
    }

    final todayX = 60.0 + (closestIdx * 120.0);
    final glowPaint = Paint()
      ..color = AppColors.blushGold.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(todayX, lineY), 12, glowPaint);

    paint
      ..style = PaintingStyle.fill
      ..color = AppColors.blushGold;
    canvas.drawCircle(Offset(todayX, lineY), 4, paint);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) => true;
}

/// A single milestone node on the timeline.
class _TimelineNode extends StatelessWidget {
  final Milestone milestone;
  final bool isFirst;
  final bool isLast;

  const _TimelineNode({
    required this.milestone,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Category emoji
          Text(milestone.category.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          // Date
          Text(
            DateFormat('MMM d').format(milestone.date),
            style: AppTypography.outfitBold.copyWith(
              fontSize: 10,
              color: AppColors.blushGold.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          // Node circle (interactive)
          Semantics(
            label:
                'Milestone: ${milestone.title}, ${DateFormat.yMMMd().format(milestone.date)}',
            button: true,
            child: GestureDetector(
              onTap: () {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: '',
                  barrierColor: AppColors.inkDeep.withValues(alpha: 0.72),
                  transitionDuration: const Duration(milliseconds: 400),
                  pageBuilder: (context, anim1, anim2) {
                    return MemoryDetailOverlay(milestone: milestone);
                  },
                );
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.deepRose.withValues(alpha: 0.3),
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepRose.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: milestone.imageUrls.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          milestone.imageUrls.first,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: AppColors.roseQuartz,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: AppColors.roseQuartz,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              milestone.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 11,
                color: AppColors.petalWhite.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gallery view (the existing carousel style).
class _GalleryView extends StatelessWidget {
  final List<Milestone> milestones;

  const _GalleryView({required this.milestones});

  @override
  Widget build(BuildContext context) {
    final pageController = PageController(viewportFraction: 0.85);

    return SizedBox(
      height: 300,
      child: PageView.builder(
        controller: pageController,
        itemCount: milestones.length,
        itemBuilder: (context, index) {
          final milestone = milestones[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: '',
                  barrierColor: AppColors.inkDeep.withValues(alpha: 0.72),
                  transitionDuration: const Duration(milliseconds: 400),
                  pageBuilder: (context, anim1, anim2) {
                    return MemoryDetailOverlay(milestone: milestone);
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(
                    alpha: AppTheme.glassOpacity,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    if (milestone.imageUrls.isNotEmpty)
                      Expanded(
                        flex: 2,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Image.network(
                            milestone.imageUrls.first,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.deepRose.withValues(alpha: 0.1),
                              child: Center(
                                child: Icon(
                                  Icons.image,
                                  color: AppColors.roseQuartz.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  milestone.category.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    milestone.title,
                                    style: AppTypography.cormorantBold.copyWith(
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              DateFormat('MMMM d, yyyy').format(milestone.date),
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 12,
                                color: AppColors.blushGold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                milestone.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitWhite.copyWith(
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}