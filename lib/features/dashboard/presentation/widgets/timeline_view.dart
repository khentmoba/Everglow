import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'package:intl/intl.dart';
import '../../domain/models/milestone.dart';
import '../../data/services/milestone_service.dart';
import './memory_detail_view.dart';
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
        // Section header — candlelit keepsake masthead.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.sm,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.06),
                  borderRadius: AppRadius.radiusFull,
                  border: Border.all(
                    color: AppColors.moonlight.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 10,
                      color: AppColors.auroraRose,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FOR CLAIR',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 10,
                        letterSpacing: 3.0,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.blushGold.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text(
                      'LIVING ARCHIVE',
                      style: AppTypography.cormorantBlack.copyWith(
                        fontSize: 26,
                        letterSpacing: 3.0,
                        color: AppColors.petalWhite,
                        shadows: [
                          BoxShadow(
                            color: AppColors.deepRose.withValues(alpha: 0.45),
                            blurRadius: 14,
                          ),
                          const BoxShadow(
                            color: AppColors.scrimMedium,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.blushGold.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'little moments, kept forever',
                style: AppTypography.handwrittenTitle().copyWith(
                  fontSize: 19,
                  color: AppColors.blushGold.withValues(alpha: 0.92),
                ),
              ),
              if (_milestones.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '♡ ${_milestones.length} frame${_milestones.length == 1 ? '' : 's'} kept ♡',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    color: AppColors.roseQuartz.withValues(alpha: 0.62),
                  ),
                ),
              ],
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
  int _currentImg = 0;

  @override
  void initState() {
    super.initState();
    _startImgScroll();
  }

  void _startImgScroll() {
    _imgTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (!_imgController.hasClients) return;
      if (widget.milestone.imageUrls.length <= 1) return;
      try {
        if (!_imgController.position.hasContentDimensions) return;
        final current = _imgController.page?.round() ?? _currentImg;
        final next = current + 1;
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
      } catch (_) {
        return;
      }
    });
  }

  @override
  void dispose() {
    _imgTimer?.cancel();
    _imgController.dispose();
    super.dispose();
  }

  void _openMemory() {
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
  }

  @override
  Widget build(BuildContext context) {
    final milestone = widget.milestone;
    final imageCount = milestone.imageUrls.length;

    return Semantics(
      button: true,
      label: 'Open memory ${milestone.title}',
      child: GestureDetector(
        onTap: _openMemory,
        child: Container(
          width: 320,
          height: 500,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.silk, AppColors.velvet, AppColors.inkDeep],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: AppRadius.radiusX3,
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.32),
            ),
            boxShadow: [
              ...AppElevation.e3,
              ...AppElevation.glowRose,
              BoxShadow(
                color: AppColors.blushGold.withValues(alpha: 0.10),
                blurRadius: 14,
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.radiusX3,
            child: Column(
              children: [
                // Candlelight hairline — warm glow across the top.
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.blushGold.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Film leader (top)
                _buildFilmStripEdge(isTop: true),

                // Photo — full-bleed with scrims + floating keepsake pills.
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (milestone.imageUrls.isEmpty)
                        Container(
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
                      else
                        PageView.builder(
                          controller: _imgController,
                          padEnds: false,
                          itemCount: imageCount,
                          onPageChanged: (i) => setState(() => _currentImg = i),
                          itemBuilder: (context, idx) =>
                              _buildImage(milestone.imageUrls[idx]),
                        ),

                      // Top scrim for pill legibility.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 72,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.inkDeep.withValues(alpha: 0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom scrim — melts the photo into the story below.
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.inkDeep.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Category keepsake pill.
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.inkDeep.withValues(alpha: 0.62),
                            borderRadius: AppRadius.radiusFull,
                            border: Border.all(
                              color: AppColors.moonlight.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                milestone.category.emoji,
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                milestone.category.displayName.toUpperCase(),
                                style: AppTypography.outfitHeading.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1.4,
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.92,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Photo counter.
                      if (imageCount > 1)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.inkDeep.withValues(alpha: 0.62),
                              borderRadius: AppRadius.radiusFull,
                              border: Border.all(
                                color: AppColors.moonlight.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_rounded,
                                  size: 11,
                                  color: AppColors.blushGold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_currentImg + 1} / $imageCount',
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                    color: AppColors.petalWhite.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Date candle — gold pill stamped on the photo.
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.auroraGold,
                            borderRadius: AppRadius.radiusFull,
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.scrimMedium,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 13,
                                color: AppColors.inkDeep,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                DateFormat(
                                  'MMM d, yyyy',
                                ).format(milestone.date).toUpperCase(),
                                style: AppTypography.outfitHeading.copyWith(
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                  color: AppColors.inkDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Image dots.
                      if (imageCount > 1 && imageCount <= 6)
                        Positioned(
                          right: 12,
                          bottom: 18,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(imageCount, (i) {
                              final active = i == _currentImg;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(left: 5),
                                width: active ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.auroraGold
                                      : AppColors.moonlight.withValues(
                                          alpha: 0.4,
                                        ),
                                  borderRadius: AppRadius.radiusFull,
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),

                // Story.
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cormorantBoldWhite.copyWith(
                            fontSize: 22,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppColors.auroraGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                milestone.author != null
                                    ? 'Memory by ${milestone.author} ♡'
                                    : 'Kept with love ♡',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.3,
                                  color: AppColors.blushGold.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          milestone.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite.withValues(alpha: 0.78),
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Open our story',
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 12,
                                    letterSpacing: 0.4,
                                    color: AppColors.blushGold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: AppColors.blushGold,
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.favorite_rounded,
                              size: 14,
                              color: AppColors.auroraRose,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Film leader (bottom)
                _buildFilmStripEdge(isTop: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilmStripEdge({required bool isTop}) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.6),
        border: isTop
            ? Border(
                bottom: BorderSide(
                  color: AppColors.blushGold.withValues(alpha: 0.16),
                ),
              )
            : Border(
                top: BorderSide(
                  color: AppColors.blushGold.withValues(alpha: 0.16),
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          8,
          (index) => Container(
            width: 22,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.14),
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.scrimMedium,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover, width: double.infinity);
    }
    return Image.network(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      cacheWidth: 600,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.silk,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.blushGold,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) {
        return Container(
          color: AppColors.deepRose.withValues(alpha: 0.08),
          child: Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: AppColors.roseQuartz.withValues(alpha: 0.4),
              size: 28,
            ),
          ),
        );
      },
    );
  }
}
