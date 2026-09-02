import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../../domain/models/milestone.dart';
import '../../data/services/milestone_service.dart';
import './memory_detail_view.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../core/theme/app_typography.dart';

class TimelineView extends StatefulWidget {
  const TimelineView({super.key});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final PageController _pageController = PageController(
    viewportFraction: 0.85,
    initialPage: 0,
  );
  Timer? _autoScrollTimer;
  Timer? _retryTimer;
  StreamSubscription<List<Milestone>>? _sub;
  final MilestoneService _milestoneService = MilestoneService();
  int _milestonesCount = 0;
  List<Milestone> _milestones = const [];
  bool _hasError = false;
  bool _isLoading = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _startAutoScroll();
  }

  void _subscribe() {
    _sub?.cancel();
    _retryTimer?.cancel();
    _sub = _milestoneService.milestones.listen(
      (data) {
        if (!mounted) return;
        _retryCount = 0;
        setState(() {
          _milestones = data;
          _milestonesCount = data.length;
          _hasError = false;
          _isLoading = false;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        if (_retryCount < _maxRetries) {
          _retryCount++;
          _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
            if (mounted) _subscribe();
          });
        } else {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      },
      onDone: () {
        // withFirestoreTimeout can close without error after 5s if the
        // first snapshot never arrived (offline/permission race). Treat a
        // closed stream with no data as a retryable error so the skeleton
        // doesn't stay forever.
        if (!mounted) return;
        if (_milestones.isEmpty && !_hasError) {
          if (_retryCount < _maxRetries) {
            _retryCount++;
            _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
              if (mounted) _subscribe();
            });
          } else {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          }
        }
      },
    );
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (!_pageController.hasClients) return;
      final count = _milestonesCount;
      if (count <= 1) return;
      // Guard hasContentDimensions before reading `page` — on first frame
      // `position` is not yet attached and accessing `page` would throw
      // "PageController not attached" which surfaces as the grey
      // "Something went dark" overlay. On web this was previously surfaced
      // as a RangeError / Stack Overflow in CanvasKit.
      double currentPage = 0;
      try {
        if (_pageController.position.hasContentDimensions) {
          currentPage = _pageController.page ?? 0;
        }
      } catch (_) {
        return;
      }
      final current = currentPage.round();
      // Clamp current to valid range — Firestore can shrink the list while
      // the controller is mid-animation (e.g. admin deletes a milestone).
      final clampedCurrent = current.clamp(0, count - 1);
      final next = (clampedCurrent + 1) % count;
      if (next == 0) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      } else {
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
    _retryTimer?.cancel();
    _sub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildCarousel() {
    if (_hasError) {
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
              'Could not load memories',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.roseQuartz.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _subscribe();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.deepRose.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.deepRose.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: AppColors.petalWhite,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Retry',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppColors.petalWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
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

    final milestones = _milestones;
    if (milestones.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: PageView.builder(
        controller: _pageController,
        // Do not keep huge offscreen cache on web — with viewportFraction 0.85
        // the default cache would lay out neighboring pages + their image
        // carousels, which blew the SkWasm stack when itemCount was 10000
        // and still janks with smaller lists. Keep only the visible page.
        // ClampingScrollPhysics prevents the PageView from fighting the
        // outer CustomScrollView's vertical drag (gesture arena stack
        // overflow seen as k1.IT/Ld at framework.dart:6944).
        physics: const ClampingScrollPhysics(),
        clipBehavior: Clip.hardEdge,
        allowImplicitScrolling: false,
        padEnds: false,
        itemCount: milestones.length,
        itemBuilder: (context, index) {
          final milestone = milestones[index];
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              // hasClients must be checked before touching `position` or `page`
              // on the first frame the PageView is not yet attached and
              // reading `position` throws — previously surfaced as the grey
              // "Something went dark" overlay and as RangeError/Stack Overflow
              // on CanvasKit/SkWasm.
              if (_pageController.hasClients) {
                try {
                  if (_pageController.position.hasContentDimensions) {
                    final page = _pageController.page;
                    if (page != null) {
                      value = (page - index).abs();
                      value = (1 - (value * 0.15)).clamp(0.0, 1.0);
                    }
                  } else {
                    value = (index == 0) ? 1.0 : 0.85;
                  }
                } catch (_) {
                  value = (index == 0) ? 1.0 : 0.85;
                }
              } else {
                value = (index == 0) ? 1.0 : 0.85;
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
      ),
    );
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
              Expanded(
                child: Divider(
                  color: AppColors.blushGold.withValues(alpha: 0.15),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'LIVING ARCHIVE',
                  style: AppTypography.cormorantBlack.copyWith(
                    fontSize: 22,
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

        // Carousel Container
        SizedBox(height: 520, child: _buildCarousel()),
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
      if (!mounted) return;
      if (_imgController.hasClients && widget.milestone.imageUrls.length > 1) {
        int next = (_imgController.page?.round() ?? 0) + 1;
        if (next >= widget.milestone.imageUrls.length) {
          _imgController.animateToPage(
            0,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
          );
        } else {
          _imgController.nextPage(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
          );
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
          barrierColor: AppColors.inkDeep.withValues(alpha: 0.72),
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
                      child: widget.milestone.imageUrls.isEmpty
                          ? Container(
                              color: AppColors.deepRose.withValues(alpha: 0.08),
                              child: Center(
                                child: Icon(
                                  Icons.image_rounded,
                                  color: AppColors.roseQuartz.withValues(
                                    alpha: 0.3,
                                  ),
                                  size: 32,
                                ),
                              ),
                            )
                          : PageView.builder(
                              controller: _imgController,
                              padEnds: false,
                              itemCount: widget.milestone.imageUrls.length,
                              itemBuilder: (context, idx) =>
                                  _buildImage(widget.milestone.imageUrls[idx]),
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
                              style: AppTypography.cormorantBold.copyWith(
                                fontSize: 22,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'MMMM d, yyyy',
                              ).format(widget.milestone.date),
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 13,
                                color: AppColors.blushGold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.milestone.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.outfitWhite.copyWith(
                                color: AppColors.petalWhite.withValues(
                                  alpha: 0.8,
                                ),
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
        children: List.generate(
          8,
          (index) => Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('assets/')) return Image.asset(path, fit: BoxFit.cover);
    return Image.network(path, fit: BoxFit.cover, cacheWidth: 300);
  }
}
