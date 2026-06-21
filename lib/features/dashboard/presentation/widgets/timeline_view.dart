import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/features/dashboard/domain/models/milestone.dart';
import 'package:everglow/features/dashboard/data/services/milestone_service.dart';
import 'package:everglow/features/dashboard/presentation/widgets/memory_detail_view.dart';
import 'package:everglow/shared/widgets/glass_container.dart';
import 'package:everglow/core/theme/app_theme.dart';

class TimelineView extends StatefulWidget {
  const TimelineView({super.key});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final PageController _pageController = PageController(viewportFraction: 0.85, initialPage: 5000);
  Timer? _autoScrollTimer;
  final MilestoneService _milestoneService = MilestoneService();

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Row(
            children: [
              Expanded(child: Divider(color: AppTheme.blushGold.withValues(alpha: 0.15), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'LIVING ARCHIVE',
                  style: GoogleFonts.cormorantGaramond(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: AppTheme.roseQuartz,
                    letterSpacing: 2.0,
                    shadows: [
                      BoxShadow(color: AppTheme.deepRose.withValues(alpha: 0.5), blurRadius: 10),
                    ],
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppTheme.blushGold.withValues(alpha: 0.15), thickness: 1)),
            ],
          ),
        ),

        // Carousel Container
        SizedBox(
          height: 520,
          child: StreamBuilder<List<Milestone>>(
            stream: _milestoneService.milestones,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 32, color: AppTheme.roseQuartz.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      Text(
                        'Could not load memories',
                        style: GoogleFonts.outfit(color: AppTheme.roseQuartz.withValues(alpha: 0.6), fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.deepRose.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Loading memories...',
                        style: GoogleFonts.outfit(
                          color: AppTheme.roseQuartz.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final milestones = snapshot.data ?? [];
              if (milestones.isEmpty) {
                return const SizedBox.shrink();
              }

              return PageView.builder(
                controller: _pageController,
                itemBuilder: (context, index) {
                  final milestone = milestones[index % milestones.length];
                  
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (_pageController.position.hasContentDimensions) {
                        value = (_pageController.page! - index).abs();
                        value = (1 - (value * 0.15)).clamp(0.0, 1.0);
                      } else {
                        value = (index == 5000) ? 1.0 : 0.85;
                      }

                      return Center(
                        child: Transform.scale(
                          scale: value,
                          child: Opacity(
                            opacity: value.clamp(0.5, 1.0),
                            child: _MilestoneCarouselCard(milestone: milestone),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MilestoneCarouselCard extends StatefulWidget {
  final Milestone milestone;
  const _MilestoneCarouselCard({required this.milestone});

  @override
  State<_MilestoneCarouselCard> createState() => _MilestoneCarouselCardState();
}

class _MilestoneCarouselCardState extends State<_MilestoneCarouselCard> {
  final PageController _imgController = PageController();
  Timer? _imgTimer;

  @override
  void initState() {
    super.initState();
    _startImgScroll();
  }

  void _startImgScroll() {
    _imgTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_imgController.hasClients && widget.milestone.imageUrls.length > 1) {
        int next = (_imgController.page?.round() ?? 0) + 1;
        if (next >= widget.milestone.imageUrls.length) {
          _imgController.animateToPage(0, duration: const Duration(milliseconds: 1000), curve: Curves.easeInOut);
        } else {
          _imgController.nextPage(duration: const Duration(milliseconds: 1000), curve: Curves.easeInOut);
        }
      }
    });
  }

  @override
  void dispose() {
    _imgTimer?.cancel();
    _imgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: '',
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, anim1, anim2) {
            return MemoryDetailOverlay(milestone: widget.milestone);
          },
        );
      },
      child: GlassContainer(
        width: 320,
        height: 500,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            // Film Header
            _buildFilmStripEdge(),
            
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: PageView.builder(
                        controller: _imgController,
                        itemCount: widget.milestone.imageUrls.length,
                        itemBuilder: (context, idx) => _buildImage(widget.milestone.imageUrls[idx]),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.milestone.title,
                              style: GoogleFonts.cormorantGaramond(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: AppTheme.roseQuartz,
                              ),
                            ),
                            Text(
                              DateFormat('MMMM d, yyyy').format(widget.milestone.date),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppTheme.blushGold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.milestone.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: AppTheme.petalWhite.withValues(alpha: 0.8),
                                height: 1.4,
                                fontSize: 13,
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
            
            // Film Footer
            _buildFilmStripEdge(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilmStripEdge() {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(8, (index) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppTheme.moonlight.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        )),
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('assets/')) return Image.asset(path, fit: BoxFit.cover);
    return Image.network(path, fit: BoxFit.cover);
  }
}
