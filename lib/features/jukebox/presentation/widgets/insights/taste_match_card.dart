import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../providers/music_insights_provider.dart';
import '../../../data/models/top_artist.dart';

class TasteMatchCard extends StatelessWidget {
  const TasteMatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicInsightsProvider>(
      builder: (context, p, _) {
        if (p.isLoading && !p.hasAny) return const _TasteSkeleton();
        final score = p.compatibilityScore;
        final shared = p.sharedArtists;
        final khentUnique = p.khentUniqueArtists;
        final clairUnique = p.clairUniqueArtists;

        // vibe label
        final vibe = switch (score) {
          >= 80 => 'Soul Twins',
          >= 60 => 'Harmonic',
          >= 40 => 'Curious Blend',
          >= 20 => 'Opposite Attract',
          _ => 'Just Starting',
        };

        return Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.velvet.withValues(alpha: 0.92),
                AppColors.inkDeep.withValues(alpha: 0.92),
                const Color(0xFF1E1030).withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(color: AppColors.inkDeep.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 10)),
              BoxShadow(color: AppColors.auroraLilac.withValues(alpha: 0.08), blurRadius: 32, spreadRadius: -6),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.radiusX2,
            child: Stack(
              children: [
                // ambient orbs
                Positioned(top: -30, left: -20, child: _Glow(color: AppColors.auroraRose, size: 180)),
                Positioned(bottom: -40, right: -30, child: _Glow(color: AppColors.auroraLilac, size: 220)),
                Positioned.fill(child: CustomPaint(painter: _GrainPainter())),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [Color(0xFFFF7AA2), Color(0xFFB79CED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
                              boxShadow: [BoxShadow(color: AppColors.auroraRose.withValues(alpha: 0.35), blurRadius: 16)],
                            ),
                            child: const Icon(Icons.favorite_rounded, size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TASTE MATCH', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 1.8, color: AppColors.blushGold)),
                                Text('How in sync are you?', style: AppTypography.outfitMedium.copyWith(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.auroraLilac.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.auroraLilac.withValues(alpha: 0.28))),
                            child: Row(children: [
                              const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.auroraLilac),
                              const SizedBox(width: 4),
                              Text(vibe.toUpperCase(), style: AppTypography.outfitBold.copyWith(fontSize: 9, letterSpacing: 1.0, color: AppColors.auroraLilac)),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      LayoutBuilder(builder: (context, c) {
                        final isNarrow = c.maxWidth < 520;
                        if (isNarrow) {
                          return Column(
                            children: [
                              Center(child: _ScoreRing(score: score)),
                              const SizedBox(height: AppSpacing.xl),
                              _SharedStrip(artists: shared),
                              const SizedBox(height: AppSpacing.lg),
                              _SplitColumns(khentUnique: khentUnique, clairUnique: clairUnique),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ScoreRing(score: score),
                            const SizedBox(width: AppSpacing.xl),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SharedStrip(artists: shared),
                                  const SizedBox(height: AppSpacing.lg),
                                  _SplitColumns(khentUnique: khentUnique, clairUnique: clairUnique),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                      if (shared.isEmpty && p.hasAny) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: AppRadius.radiusMd, border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                          child: Text('No shared artists in your top 50 yet — keep exploring together and your Venn will bloom.',
                              style: AppTypography.outfitMedium.copyWith(fontSize: 12, color: AppColors.textMedium, height: 1.4)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreRing extends StatefulWidget {
  final int score;
  const _ScoreRing({required this.score});
  @override
  State<_ScoreRing> createState() => _ScoreRingState();
}

class _ScoreRingState extends State<_ScoreRing> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant _ScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.score;
    return SizedBox(
      width: 148,
      height: 148,
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, __) {
          final v = _a.value * score / 100;
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 148,
                height: 148,
                child: CustomPaint(
                  painter: _RingPainter(progress: v),
                ),
              ),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.inkDeep.withValues(alpha: 0.9), AppColors.velvet.withValues(alpha: 0.9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [BoxShadow(color: AppColors.auroraRose.withValues(alpha: 0.18), blurRadius: 18)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${(v * 100).round()}%', style: AppTypography.cormorantBoldWhite.copyWith(fontSize: 32, height: 1.0, shadows: [Shadow(color: AppColors.auroraRose.withValues(alpha: 0.35), blurRadius: 12)])),
                    const SizedBox(height: 2),
                    Text('in sync', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 1.4, color: AppColors.blushGold.withValues(alpha: 0.9))),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 10,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.auroraGold, border: Border.all(color: Colors.white.withValues(alpha: 0.8))),
                  child: const Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFF6B4E00)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0xFFFF7AA2), Color(0xFFF5C97B), Color(0xFFB79CED), Color(0xFFFF7AA2)],
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    final sweep = 2 * math.pi * progress.clamp(0, 1);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, fg);
    // outer glow
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..color = AppColors.auroraRose.withValues(alpha: 0.10)
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, glow);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress;
}

class _SharedStrip extends StatelessWidget {
  final List<TopArtist> artists;
  const _SharedStrip({required this.artists});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.groups_rounded, size: 14, color: AppColors.auroraGold),
          const SizedBox(width: 6),
          Text('YOU BOTH LOVE', style: AppTypography.outfitBold.copyWith(fontSize: 10, letterSpacing: 1.4, color: AppColors.auroraGold)),
          const SizedBox(width: 8),
          Container(height: 1, width: 28, color: AppColors.auroraGold.withValues(alpha: 0.25)),
        ]),
        const SizedBox(height: 10),
        if (artists.isEmpty)
          Text('—', style: AppTypography.outfitMedium.copyWith(color: AppColors.textMuted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: artists.map((a) => _ArtistChip(artist: a, isShared: true)).toList(),
          ),
      ],
    );
  }
}

class _SplitColumns extends StatelessWidget {
  final List<TopArtist> khentUnique;
  final List<TopArtist> clairUnique;
  const _SplitColumns({required this.khentUnique, required this.clairUnique});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _MiniColumn(title: "KHENT'S CORNER", artists: khentUnique, color: AppColors.auroraTeal, icon: Icons.person_rounded)),
        const SizedBox(width: 12),
        Container(width: 1, height: 92, color: Colors.white.withValues(alpha: 0.06)),
        const SizedBox(width: 12),
        Expanded(child: _MiniColumn(title: "CLAIR'S CORNER", artists: clairUnique, color: AppColors.cinemaPink, icon: Icons.person_rounded)),
      ],
    );
  }
}

class _MiniColumn extends StatelessWidget {
  final String title;
  final List<TopArtist> artists;
  final Color color;
  final IconData icon;
  const _MiniColumn({required this.title, required this.artists, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(title, style: AppTypography.outfitBold.copyWith(fontSize: 9, letterSpacing: 1.0, color: color)),
        ]),
        const SizedBox(height: 8),
        if (artists.isEmpty)
          Text('—', style: AppTypography.outfitMedium.copyWith(fontSize: 11, color: AppColors.textMuted))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: artists.map((a) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• ${a.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.outfitMedium.copyWith(fontSize: 11.5, color: AppColors.petalWhite.withValues(alpha: 0.85))))).toList(),
          ),
      ],
    );
  }
}

class _ArtistChip extends StatelessWidget {
  final TopArtist artist;
  final bool isShared;
  const _ArtistChip({required this.artist, required this.isShared});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.auroraGold.withValues(alpha: 0.18), AppColors.auroraGold.withValues(alpha: 0.06)]),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.auroraGold.withValues(alpha: 0.32)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.music_note_rounded, size: 11, color: AppColors.auroraGold),
        const SizedBox(width: 4),
        Text(artist.name, style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppColors.petalWhite)),
        const SizedBox(width: 6),
        Text('${artist.playCount}', style: AppTypography.outfitMedium.copyWith(fontSize: 10, color: AppColors.blushGold)),
      ]),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: 0.18), Colors.transparent])),
      );
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.012);
    for (var i = 0; i < 120; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 0.8 + 0.3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TasteSkeleton extends StatelessWidget {
  const _TasteSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 220,
        decoration: BoxDecoration(color: AppColors.shimmerBase, borderRadius: AppRadius.radiusX2),
      );
}
