import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_spacing.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/shared/widgets/everglow/everglow_background.dart';
import 'package:everglow/shared/widgets/everglow/everglow_feature_header.dart';

import '../../data/services/mochi_today_service.dart';
import '../../domain/memory/memory_retrieval.dart';
import '../../domain/memory/today_recap.dart';

/// Mochi Today — the connective-layer recap. One screen that answers
/// "what is happening with us" from every part of Everglow and shows
/// the gentle patterns Mochi notices.
class MochiTodayScreen extends StatefulWidget {
  const MochiTodayScreen({super.key});

  @override
  State<MochiTodayScreen> createState() => _MochiTodayScreenState();
}

class _MochiTodayScreenState extends State<MochiTodayScreen> {
  final MochiTodayService _service = MochiTodayService();
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
            showPetals: true,
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
                  title: 'Mochi Today',
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.auroraGold),
      );
    }
    final snapshot = _snapshot!;
    final date = snapshot.date;
    final dateLabel = '${date.year.toString().padLeft(4, '0')}-'
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
          child: Text(
            recap,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 15,
              height: 1.5,
            ),
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
                          backgroundColor:
                              AppColors.auroraRose.withValues(alpha: 0.12),
                          side: BorderSide(
                            color:
                                AppColors.auroraRose.withValues(alpha: 0.4),
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
                ...snapshot.watchlist
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          '🎬 $w',
                          style: AppTypography.outfitMedium,
                        ),
                      ),
                    )
              else
                const _EmptyLine('Watchlist is quiet right now.'),
              if (snapshot.starlight.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                ...snapshot.starlight.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      '✨ "$s"',
                      style: AppTypography.outfitMedium,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (insights.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'What Mochi notices',
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
