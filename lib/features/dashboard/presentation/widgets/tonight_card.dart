import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_button.dart';
import '../../../tonight/data/models/tonight_decision.dart';
import '../../../tonight/data/models/tonight_option.dart';
import '../../../tonight/data/services/tonight_service.dart';
import 'feature_section.dart';

class TonightCard extends StatefulWidget {
  final TonightDecision? previewDecision;

  const TonightCard({super.key, this.previewDecision});

  @override
  State<TonightCard> createState() => _TonightCardState();
}

class _TonightCardState extends State<TonightCard> {
  final TonightService _service = TonightService();

  @override
  Widget build(BuildContext context) {
    return FeatureSection(
      icon: Icons.bedtime_outlined,
      hue: AppColors.roseQuartz,
      title: 'Tonight',
      subtitle: 'A little time for us',
      onTap: () => context.push('/tonight'),
      trailing: IconButton(
        tooltip: 'Choose tonight',
        icon: const Icon(
          Icons.arrow_forward_rounded,
          color: AppColors.roseQuartz,
        ),
        onPressed: () => context.push('/tonight'),
      ),
      child: StreamBuilder<TonightDecision?>(
        initialData: widget.previewDecision,
        stream: widget.previewDecision == null
            ? _service.watchActiveDecision()
            : Stream.value(widget.previewDecision),
        builder: (context, snapshot) {
          final decision = snapshot.data;
          if (decision == null || decision.options.isEmpty) {
            return _buildReadyState(context);
          }
          if (decision.status != TonightStatus.voting &&
              decision.winningOption != null) {
            return _buildWinnerState(context, decision);
          }
          return _buildVotingState(decision);
        },
      ),
    );
  }

  Widget _buildReadyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A movie, a date, or a little friendly competition. Let’s find our evening.',
          style: AppTypography.bodyMedium().copyWith(height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        EverglowButton(
          label: 'Find our tonight',
          icon: Icons.auto_awesome_rounded,
          backgroundColor: AppColors.roseQuartz,
          foregroundColor: AppColors.inkDeep,
          onPressed: () => context.push('/tonight'),
        ),
      ],
    );
  }

  Widget _buildVotingState(TonightDecision decision) {
    final status = decision.votes.isEmpty
        ? 'Three ideas. Which one feels like us?'
        : decision.isTied
        ? 'Two different picks · Choose together'
        : decision.votes.length == 1
        ? 'One wish is in · Waiting for the other'
        : 'Both wishes are in';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          status,
          style: AppTypography.bodySmall().copyWith(color: AppColors.blushGold),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final option in decision.options) ...[
          _buildOptionSummary(option, decision),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildWinnerState(BuildContext context, TonightDecision decision) {
    final winner = decision.winningOption!;
    final planned = decision.status == TonightStatus.planned;
    final hue = planned ? AppColors.auroraTeal : AppColors.blushGold;
    final time = decision.planTime == null
        ? 'Tonight'
        : DateFormat('h:mm a').format(decision.planTime!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          planned
              ? 'Our evening · $time'
              : decision.isMatch
              ? 'It’s a match.'
              : 'Our pick for tonight',
          style: AppTypography.labelMedium().copyWith(color: hue),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          winner.title,
          style: AppTypography.headlineSmall().copyWith(
            color: AppColors.petalWhite,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: EverglowButton(
            label: !planned
                ? 'Save our plan'
                : switch (winner.type) {
                    TonightOptionType.movie => 'Open Cinema',
                    TonightOptionType.game => 'Play together',
                    TonightOptionType.date => 'View Calendar',
                  },
            icon: planned
                ? Icons.arrow_forward_rounded
                : Icons.calendar_month_rounded,
            backgroundColor: hue,
            foregroundColor: AppColors.inkDeep,
            onPressed: () => context.push(
              planned ? winner.targetRoute ?? '/calendar' : '/tonight',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionSummary(TonightOption option, TonightDecision decision) {
    final votes = decision.votes.values.where((v) => v == option.id).length;
    final hue = switch (option.type) {
      TonightOptionType.movie => AppColors.auroraLilac,
      TonightOptionType.date => AppColors.roseQuartz,
      TonightOptionType.game => AppColors.blushGold,
    };
    final icon = switch (option.type) {
      TonightOptionType.movie => Icons.movie_outlined,
      TonightOptionType.date => Icons.favorite_border_rounded,
      TonightOptionType.game => Icons.sports_esports_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.06),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: votes > 0 ? hue.withValues(alpha: 0.45) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: hue, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              option.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textHigh,
              ),
            ),
          ),
          if (votes > 0) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$votes',
              style: AppTypography.labelSmall().copyWith(color: hue),
            ),
            const SizedBox(width: 4),
            Icon(Icons.favorite_rounded, color: hue, size: 12),
          ],
        ],
      ),
    );
  }
}
