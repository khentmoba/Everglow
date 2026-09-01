import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/env_config.dart';
import '../providers/jukebox_provider.dart';
import 'music_card.dart';
import '../../data/models/music_status.dart';

import 'package:marquee/marquee.dart';
import 'package:confetti/confetti.dart';
import 'vinyl_record.dart';
import 'spotify_connect_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_motion.dart';

class JukeboxWidget extends StatefulWidget {
  const JukeboxWidget({super.key});

  @override
  State<JukeboxWidget> createState() => _JukeboxWidgetState();
}

class _JukeboxWidgetState extends State<JukeboxWidget>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _ambientController;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _ambientController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  bool _shouldTrigger(MusicStatus s) => s.isPlaying && s.artistName.toLowerCase() == 'ethel cain';

  void _triggerHearts(MusicStatus status) {
    if (status.isPlaying && status.artistName.toLowerCase() == 'ethel cain') {
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final khentUser = EnvConfig.lastfmUserKhent;
    final clairUser = EnvConfig.lastfmUserClair;

    return StreamBuilder<Map<String, MusicStatus>>(
      stream: context.read<JukeboxProvider>().statusStream,
      builder: (context, snapshot) {
        final statuses = snapshot.data ?? {};
        final khentStatus = statuses[khentUser] ?? MusicStatus.empty(khentUser);
        final clairStatus = statuses[clairUser] ?? MusicStatus.empty(clairUser);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_shouldTrigger(khentStatus)) _triggerHearts(khentStatus);
          if (_shouldTrigger(clairStatus)) _triggerHearts(clairStatus);
        });

        final bool eitherLive = khentStatus.isPlaying || clairStatus.isPlaying;

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([
                _ambientController,
                _entranceController,
              ]),
              builder: (context, child) {
                final e = CurvedAnimation(
                  parent: _entranceController,
                  curve: AppMotion.easeOutExpo,
                ).value;
                return Opacity(
                  opacity: e,
                  child: Transform.translate(
                    offset: Offset(0, (1 - e) * 14),
                    child: child,
                  ),
                );
              },
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.radiusX2,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.velvet.withValues(alpha: 0.78),
                          AppColors.inkDeep.withValues(alpha: 0.82),
                          const Color(0xFF1E1230).withValues(alpha: 0.78),
                        ],
                      ),
                      border: Border.all(
                        color: eitherLive
                            ? AppColors.moonlight.withValues(alpha: 0.18)
                            : AppColors.moonlight.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.inkDeep.withValues(alpha: 0.5),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                        if (eitherLive)
                          BoxShadow(
                            color: AppColors.deepRose.withValues(alpha: 0.11),
                            blurRadius: 36,
                            spreadRadius: -4,
                          ),
                      ],
                    ),
                    clipBehavior: Clip.none,
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: AppRadius.radiusX2,
                      child: Stack(
                        children: [
                          Positioned(
                            top: -40,
                            left: -30,
                            child: _GlowOrb(
                              color: AppColors.deepRose,
                              size: 180,
                              t:
                                  (_ambientController.value * 2 * math.pi) %
                                  (2 * math.pi),
                            ),
                          ),
                          Positioned(
                            bottom: -50,
                            right: -20,
                            child: _GlowOrb(
                              color: AppColors.auroraLilac,
                              size: 220,
                              t:
                                  (_ambientController.value * 2 * math.pi +
                                      1.2) %
                                  (2 * math.pi),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(painter: _GrainPainter()),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.04),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _JukeboxHeader(eitherLive: eitherLive),
                        const SizedBox(height: 12),
                        const SpotifyConnectCard(),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isMobile = constraints.maxWidth < 620;

                            Widget buildCard(MusicStatus status, String title) {
                              final delay = title.contains('Khent') ? 0 : 90;
                              return _StaggeredEntrance(
                                controller: _entranceController,
                                delayMs: delay,
                                child: MusicCard(
                                  status: status,
                                  title: title,
                                  vinylWidget: VinylRecord(
                                    isPlaying: status.isPlaying,
                                  ),
                                  marqueeWidget:
                                      status.trackName.length > 999 &&
                                          status.isPlaying
                                      ? SizedBox(
                                          height: 24,
                                          child: Marquee(
                                            text: status.trackName,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.petalWhite,
                                              letterSpacing: -0.2,
                                            ),
                                            scrollAxis: Axis.horizontal,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            blankSpace: 32.0,
                                            velocity: 28.0,
                                            pauseAfterRound: const Duration(
                                              seconds: 1,
                                            ),
                                            accelerationDuration:
                                                const Duration(seconds: 1),
                                            accelerationCurve: Curves.linear,
                                            decelerationDuration:
                                                const Duration(
                                                  milliseconds: 500,
                                                ),
                                            decelerationCurve: Curves.easeOut,
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            }

                            if (isMobile) {
                              return Column(
                                children: [
                                  buildCard(
                                    khentStatus,
                                    'Khent is vibing to...',
                                  ),
                                  const SizedBox(height: 14),
                                  buildCard(
                                    clairStatus,
                                    'Clair is vibing to...',
                                  ),
                                ],
                              );
                            } else {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: buildCard(
                                      khentStatus,
                                      'Khent is vibing to...',
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: buildCard(
                                      clairStatus,
                                      'Clair is vibing to...',
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.pink, Colors.redAccent, Colors.pinkAccent],
              createParticlePath: _drawHeart,
            ),
          ],
        );
      },
    );
  }

  Path _drawHeart(Size size) {
    final double width = size.width;
    final double height = size.height;
    final Path path = Path();
    path.moveTo(0.5 * width, height * 0.35);
    path.cubicTo(
      0.2 * width,
      height * 0.1,
      -0.2 * width,
      height * 0.6,
      0.5 * width,
      height,
    );
    path.cubicTo(
      1.2 * width,
      height * 0.6,
      0.8 * width,
      height * 0.1,
      0.5 * width,
      height * 0.35,
    );
    path.close();
    return path;
  }
}

class _JukeboxHeader extends StatefulWidget {
  const _JukeboxHeader({required this.eitherLive});
  final bool eitherLive;

  @override
  State<_JukeboxHeader> createState() => _JukeboxHeaderState();
}

class _JukeboxHeaderState extends State<_JukeboxHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _JukeboxHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eitherLive && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.eitherLive && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.auroraRose, AppColors.deepRose],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepRose.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: -2,
              ),
            ],
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JUKEBOX',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.petalWhite.withValues(alpha: 0.92),
              ),
            ),
            Text(
              widget.eitherLive
                  ? 'Live from Last.fm'
                  : 'What we\'re listening to',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.petalWhite.withValues(alpha: 0.52),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const Spacer(),
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = _pulse.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.eitherLive
                    ? AppColors.success.withValues(alpha: 0.12 + t * 0.06)
                    : AppColors.moonlight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: widget.eitherLive
                      ? AppColors.success.withValues(alpha: 0.24 + t * 0.12)
                      : AppColors.moonlight.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: widget.eitherLive
                          ? AppColors.success
                          : AppColors.mutedPurple.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      boxShadow: widget.eitherLive
                          ? [
                              BoxShadow(
                                color: AppColors.success.withValues(
                                  alpha: 0.55 + t * 0.25,
                                ),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.eitherLive ? 'ON AIR' : 'STANDBY',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: widget.eitherLive
                          ? AppColors.success
                          : AppColors.petalWhite.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size, required this.t});
  final Color color;
  final double size;
  final double t;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.85 + math.sin(t) * 0.15;
    return Opacity(
      opacity: 0.22 * pulse + 0.06,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.55), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.015);
    for (var i = 0; i < 180; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 0.7 + 0.3;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({
    required this.controller,
    required this.delayMs,
    required this.child,
  });

  final AnimationController controller;
  final int delayMs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = delayMs / 700.0;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final raw = controller.value;
        final t = ((raw - delay) / (1 - delay)).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, (1 - curved) * 16),
            child: child,
          ),
        );
      },
    );
  }
}
