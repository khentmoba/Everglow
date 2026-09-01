import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/music_status.dart';
import 'listen_along_popup.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';
import 'vinyl_record.dart';

class MusicCard extends StatefulWidget {
  final MusicStatus status;
  final String title;
  final Widget? vinylWidget;
  final Widget? marqueeWidget;
  final Widget? heartAnimationWidget;

  const MusicCard({
    super.key,
    required this.status,
    required this.title,
    this.vinylWidget,
    this.marqueeWidget,
    this.heartAnimationWidget,
  });

  @override
  State<MusicCard> createState() => _MusicCardState();
}

class _MusicCardState extends State<MusicCard> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;
  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _syncAnim();
  }

  @override
  void didUpdateWidget(covariant MusicCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.isPlaying != widget.status.isPlaying) _syncAnim();
  }

  void _syncAnim() {
    final live = widget.status.isPlaying;
    if (live && !AppMotion.reduced) {
      _glowController.repeat(reverse: true);
      _shimmerController.repeat();
      _floatController.repeat(reverse: true);
    } else {
      _glowController.stop();
      _shimmerController.stop();
      _floatController.stop();
      _glowController.value = 0;
      _shimmerController.value = 0;
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLive = widget.status.isPlaying;

    final double scale = _pressed ? 0.98 : (_hovered ? 1.015 : 1.0);
    final double lift = _hovered ? -3 : 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => showDialog(
          context: context,
          builder: (ctx) => ListenAlongPopup(status: widget.status),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_glowController, _floatController]),
          builder: (context, child) {
            final floatT = _floatController.value;
            return Transform.translate(
              offset: Offset(
                0,
                lift + (isLive ? math.sin(floatT * math.pi) * 1.2 : 0),
              ),
              child: AnimatedScale(
                scale: scale,
                duration: AppMotion.orZero(const Duration(milliseconds: 220)),
                curve: AppMotion.easeOutStrong,
                child: child,
              ),
            );
          },
          child: AnimatedContainer(
            duration: AppMotion.orZero(const Duration(milliseconds: 300)),
            curve: AppMotion.easeOutStrong,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusX2,
              gradient: isLive
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.moonlight.withValues(alpha: 0.18),
                        AppColors.velvet.withValues(alpha: 0.55),
                        AppColors.plum.withValues(alpha: 0.55),
                      ],
                    )
                  : null,
              color: isLive ? null : AppColors.moonlight.withValues(alpha: 0.10),
              border: Border.all(
                color: isLive
                    ? AppColors.blushGold.withValues(
                        alpha: 0.42 + _glowController.value * 0.22,
                      )
                    : AppColors.moonlight.withValues(
                        alpha: _hovered ? 0.22 : 0.14,
                      ),
                width: isLive ? 1.2 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLive ? 0.28 : 0.14),
                  blurRadius: isLive ? 22 : 14,
                  offset: const Offset(0, 8),
                ),
                if (isLive)
                  BoxShadow(
                    color: AppColors.deepRose.withValues(
                      alpha: 0.18 + _glowController.value * 0.12,
                    ),
                    blurRadius: 28,
                    spreadRadius: -6,
                  ),
                if (isLive)
                  BoxShadow(
                    color: AppColors.auroraLilac.withValues(
                      alpha: 0.10 + _glowController.value * 0.08,
                    ),
                    blurRadius: 36,
                    spreadRadius: -10,
                  ),
                if (_hovered && !isLive)
                  BoxShadow(
                    color: AppColors.moonlight.withValues(alpha: 0.06),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.radiusX2,
              child: Stack(
                children: [
                  if (isLive)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (_, _) {
                            return Transform.translate(
                              offset: Offset(
                                -220 + _shimmerController.value * 520,
                                0,
                              ),
                              child: Transform.rotate(
                                angle: -0.18,
                                child: Container(
                                  width: 120,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppColors.petalWhite.withValues(alpha: 0.0),
                                        AppColors.petalWhite.withValues(alpha: 0.08),
                                        AppColors.petalWhite.withValues(alpha: 0.0),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (isLive)
                    Positioned(
                      top: -18,
                      right: -18,
                      child: IgnorePointer(
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.auroraRose.withValues(alpha: 0.14),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isLive
                                  ? AppColors.deepRose.withValues(alpha: 0.18)
                                  : AppColors.moonlight.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isLive
                                    ? AppColors.deepRose.withValues(alpha: 0.28)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.music_note_rounded,
                                  size: 11,
                                  color: isLive
                                      ? AppColors.blushGold
                                      : AppColors.moonlight.withValues(
                                          alpha: 0.6,
                                        ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.title,
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 11,
                                    color: isLive
                                        ? AppColors.blushGold
                                        : AppColors.petalWhite.withValues(
                                            alpha: 0.72,
                                          ),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.success.withValues(
                                    alpha: 0.22,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PulsingDot(),
                                  const SizedBox(width: 5),
                                  Text(
                                    'LIVE',
                                    style: AppTypography.outfitWhite.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _EqualizerBars(active: isLive),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.moonlight.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppColors.mutedPurple.withValues(
                                        alpha: 0.9,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'OFFLINE',
                                    style: AppTypography.outfitWhite.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.petalWhite.withValues(
                                        alpha: 0.55,
                                      ),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.centerLeft,
                            children: [
                              if (isLive)
                                Positioned(
                                  right: -28,
                                  child: AnimatedOpacity(
                                    opacity: isLive ? 1 : 0,
                                    duration: const Duration(milliseconds: 400),
                                    child:
                                        widget.vinylWidget ??
                                        VinylRecord(isPlaying: isLive),
                                  ),
                                ),
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    if (isLive)
                                      BoxShadow(
                                        color: AppColors.deepRose.withValues(
                                          alpha: 0.28,
                                        ),
                                        blurRadius: 18,
                                        spreadRadius: 1,
                                      ),
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      AnimatedScale(
                                        scale: isLive ? 1.04 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 600,
                                        ),
                                        curve: AppMotion.easeOutStrong,
                                        child: widget.status.imageUrl != null
                                            ? Image.network(
                                                widget.status.imageUrl!,
                                                fit: BoxFit.cover,
                                                cacheWidth: 220,
                                                errorBuilder: (c, e, s) =>
                                                    _FallbackArt(
                                                      isLive: isLive,
                                                    ),
                                              )
                                            : _FallbackArt(isLive: isLive),
                                      ),
                                      if (!isLive)
                                        Container(
                                          color: Colors.black.withValues(
                                            alpha: 0.18,
                                          ),
                                        ),
                                      if (!isLive)
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withValues(
                                                  alpha: 0.22,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: AppColors.petalWhite.withValues(
                                                alpha: isLive ? 0.10 : 0.06,
                                              ),
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                AppColors.petalWhite.withValues(
                                                  alpha: 0.14,
                                                ),
                                                Colors.transparent,
                                                Colors.transparent,
                                                AppColors.petalWhite.withValues(
                                                  alpha: 0.06,
                                                ),
                                              ],
                                              stops: const [
                                                0.0,
                                                0.18,
                                                0.72,
                                                1.0,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isLive)
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.42,
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.petalWhite.withValues(
                                                  alpha: 0.18,
                                                ),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.play_arrow_rounded,
                                              size: 14,
                                              color: AppColors.petalWhite,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isLive)
                                Positioned(
                                  bottom: -6,
                                  left: 10,
                                  right: 10,
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(99),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 42),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.marqueeWidget != null && isLive)
                                  widget.marqueeWidget!
                                else
                                  Text(
                                    widget.status.trackName.isEmpty
                                        ? '—'
                                        : widget.status.trackName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.outfitWhite.copyWith(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: isLive
                                          ? AppColors.petalWhite
                                          : AppColors.petalWhite.withValues(
                                              alpha: 0.82,
                                            ),
                                      letterSpacing: -0.2,
                                      height: 1.1,
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.status.artistName.isEmpty
                                      ? 'Unknown Artist'
                                      : widget.status.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isLive
                                        ? AppColors.petalWhite.withValues(
                                            alpha: 0.78,
                                          )
                                        : AppColors.petalWhite.withValues(
                                            alpha: 0.62,
                                          ),
                                  ),
                                ),
                                if (widget.status.albumName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      widget.status.albumName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 11,
                                        color: AppColors.petalWhite.withValues(
                                          alpha: isLive ? 0.52 : 0.42,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 9),
                                if (isLive)
                                  Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: AppColors.blushGold.withValues(
                                            alpha: 0.9,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Tap to listen along →',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.outfitWhite
                                              .copyWith(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.blushGold
                                                    .withValues(alpha: 0.9),
                                                letterSpacing: 0.15,
                                              ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 12,
                                        color: AppColors.petalWhite.withValues(
                                          alpha: 0.42,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          widget.status.timestamp != null
                                              ? 'Last heard ${_formatTime(widget.status.timestamp!)}'
                                              : 'Not vibing right now',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.outfitWhite
                                              .copyWith(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: AppColors.petalWhite
                                                    .withValues(alpha: 0.48),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.heartAnimationWidget != null) ...[
                        const SizedBox(height: 6),
                        widget.heartAnimationWidget!,
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }
}

class _FallbackArt extends StatelessWidget {
  const _FallbackArt({required this.isLive});
  final bool isLive;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.velvet, AppColors.plum, AppColors.twilight],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 32,
          color: isLive
              ? AppColors.roseQuartz
              : AppColors.roseQuartz.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return SizedBox(
          width: 10,
          height: 10,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t) * 0.55,
                child: Transform.scale(
                  scale: 1 + t * 1.6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars({required this.active});
  final bool active;

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _bar(double phase, double t) {
    final v = (math.sin((t * 2 * math.pi) + phase) + 1) / 2;
    return 3 + v * 9;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _barW(_bar(0, t)),
            const SizedBox(width: 2),
            _barW(_bar(1.9, t)),
            const SizedBox(width: 2),
            _barW(_bar(3.8, t)),
          ],
        );
      },
    );
  }

  Widget _barW(double h) {
    return Container(
      width: 2.5,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
