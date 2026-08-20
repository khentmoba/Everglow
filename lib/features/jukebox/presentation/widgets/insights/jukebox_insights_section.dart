import 'package:flutter/material.dart';
import '../../../../../core/theme/app_spacing.dart';
import 'taste_match_card.dart';
import 'merged_timeline.dart';
import 'weekly_wrapped_card.dart';
import 'loved_tracks_section.dart';
import 'heatmap_section.dart';
import 'on_this_day_card.dart';
import 'discovery_race_card.dart';
import 'expanded_leaderboard.dart';

class JukeboxInsightsSection extends StatelessWidget {
  const JukeboxInsightsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        TasteMatchCard(),
        SizedBox(height: AppSpacing.xl),
        MergedTimeline(),
        SizedBox(height: AppSpacing.xl),
        ExpandedLeaderboard(),
        SizedBox(height: AppSpacing.xl),
        WeeklyWrappedCard(),
        SizedBox(height: AppSpacing.xl),
        LovedTracksSection(),
        SizedBox(height: AppSpacing.xl),
        HeatmapSection(),
        SizedBox(height: AppSpacing.xl),
        OnThisDayMusicCard(),
        SizedBox(height: AppSpacing.xl),
        DiscoveryRaceCard(),
      ],
    );
  }
}
