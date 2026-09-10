import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';

import '../../data/services/motchi_today_service.dart';
import '../../domain/memory/memory_retrieval.dart';
import '../../domain/memory/today_recap.dart';
import '../../../books/data/services/web_tts_service.dart';

/// Motchi Today — the connective-layer recap. One screen that answers
/// "what is happening with us" from every part of Everglow and shows
/// the gentle patterns Motchi notices.
class MotchiTodayScreen extends StatefulWidget {
  const MotchiTodayScreen({super.key});

  @override
  State<MotchiTodayScreen> createState() => _MotchiTodayScreenState();
}

class _MotchiTodayScreenState extends State<MotchiTodayScreen> {
  final MotchiTodayService _service = MotchiTodayService();
  TodaySnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snapshot = await _service.fetch();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.twilight,
      body: Stack(
        children: [
          const EverglowBackground(
            showPetals: false,
            glows: [
              RadialGlow(
                color: AppColors.auroraGold,
                alignment: Alignment(-0.75, -0.85),
                size: 0.7,
                opacity: 0.13,
              ),
              RadialGlow(
                color: AppColors.softLavender,
                alignment: Alignment(0.85, 0.9),
                size: 0.65,
                opacity: 0.10,
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Motchi Today',
                  subtitle: 'today in Everglow, in one breath',
                  icon: Icons.wb_twilight_rounded,
                  hue: AppColors.auroraGold,
                  actions: [
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() => _loading = true);
                              _load();
                            },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.auroraGold,
                      ),
                    ),
                  ],
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EverglowSkeleton(height: 120, radius: 16),
      );
    }
    final snapshot = _snapshot!;
    final date = snapshot.date;
    final dateLabel =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final recap = composeTodayRecap(
      dateLabel: dateLabel,
      moods: snapshot.moods,
      activities: snapshot.activities,
      watchlist: snapshot.watchlist,
      starlight: snapshot.starlight,
      memories: snapshot.memories,
      now: date,
    );
    final insights = const RelationshipInsights().compute(
      moods: snapshot.moods.map((m) => m.mood).toList(),
      activities: snapshot.activities,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.x2,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.auroraGold.withValues(alpha: 0.16),
                AppColors.deepRose.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: AppColors.auroraGold.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.wb_twilight_rounded,
                        size: 15,
                        color: AppColors.auroraGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TODAY IN EVERGLOW',
                        style: AppTypography.labelSmall().copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.auroraGold,
                        ),
                      ),
                    ],
                  ),
                  _TodayRecapListenButton(text: recap),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                recap,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Section(
          title: 'Moods',
          icon: Icons.favorite_rounded,
          color: AppColors.auroraRose,
          child: snapshot.moods.isEmpty
              ? const _EmptyLine('No mood logged yet today.')
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: snapshot.moods
                      .map(
                        (m) => Chip(
                          label: Text('${m.uid}: ${m.mood}'),
                          labelStyle: AppTypography.outfitMedium.copyWith(
                            fontSize: 12,
                          ),
                          backgroundColor: AppColors.auroraRose.withValues(
                            alpha: 0.12,
                          ),
                          side: BorderSide(
                            color: AppColors.auroraRose.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        _Section(
          title: 'Recent activity',
          icon: Icons.bolt_rounded,
          color: AppColors.auroraTeal,
          child: snapshot.activities.isEmpty
              ? const _EmptyLine('Nothing logged yet.')
              : Column(
                  children: snapshot.activities
                      .map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 7,
                                color: AppColors.auroraTeal,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  a,
                                  style: AppTypography.outfitMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        _Section(
          title: 'Watchlist & Starlight',
          icon: Icons.auto_stories_rounded,
          color: AppColors.softLavender,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (snapshot.watchlist.isNotEmpty)
                ...snapshot.watchlist.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text('🎬 $w', style: AppTypography.outfitMedium),
                  ),
                )
              else
                const _EmptyLine('Watchlist is quiet right now.'),
              if (snapshot.starlight.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                ...snapshot.starlight.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text('✨ "$s"', style: AppTypography.outfitMedium),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (insights.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'What Motchi notices',
            icon: Icons.psychology_rounded,
            color: AppColors.auroraGold,
            child: Column(
              children: insights
                  .map(
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🐱 ', style: TextStyle(fontSize: 14)),
                          Expanded(
                            child: Text(
                              '${i.title}: ${i.detail}',
                              style: AppTypography.outfitMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.outfitMuted);
  }
}

class _TodayRecapListenButton extends StatefulWidget {
  final String text;
  const _TodayRecapListenButton({required this.text});

  @override
  State<_TodayRecapListenButton> createState() => _TodayRecapListenButtonState();
}

class _TodayRecapListenButtonState extends State<_TodayRecapListenButton> {
  bool _speaking = false;

  void _toggle() {
    HapticFeedback.lightImpact();
    if (_speaking) {
      WebTtsService.instance.stop();
      if (mounted) setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      WebTtsService.instance.speak(
        widget.text,
        onComplete: () {
          if (mounted) setState(() => _speaking = false);
        },
      );
    }
  }

  @override
  void dispose() {
    if (_speaking) {
      WebTtsService.instance.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!WebTtsService.instance.isSupported) return const SizedBox.shrink();
    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: _speaking
              ? AppColors.auroraRose.withValues(alpha: 0.20)
              : AppColors.auroraGold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _speaking
                ? AppColors.auroraRose.withValues(alpha: 0.40)
                : AppColors.auroraGold.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
              size: 14,
              color: _speaking ? AppColors.auroraRose : AppColors.auroraGold,
            ),
            const SizedBox(width: 5),
            Text(
              _speaking ? 'Stop' : 'Listen',
              style: AppTypography.labelSmall().copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _speaking ? AppColors.auroraRose : AppColors.auroraGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
