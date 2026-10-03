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
      icon: Icons.nightlife_rounded,
      hue: AppColors.auroraRose,
      title: 'Tonight',
      subtitle: '“What should we do?”',
      onTap: () => context.push('/tonight'),
      trailing: EverglowButton.glass(
        label: 'Open',
        icon: Icons.arrow_forward_rounded,
        foregroundColor: AppColors.auroraRose,
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
            return _buildReadyToPickState(context);
          }

          if (decision.status == TonightStatus.planned &&
              decision.winningOption != null) {
            return _buildPlannedState(context, decision);
          }

          if (decision.status == TonightStatus.decided &&
              decision.winningOption != null) {
            return _buildDecidedState(context, decision);
          }

          return _buildVotingState(context, decision);
        },
      ),
    );
  }

  Widget _buildReadyToPickState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Roll 3 suggestions for tonight — a movie from your watchlist, a romantic date idea, and a co-op game.',
          style: AppTypography.bodySmall().copyWith(
            color: AppColors.moonlight.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _buildCategoryPill('🎬 Movie', AppColors.auroraTeal),
            const SizedBox(width: 6),
            _buildCategoryPill('🌹 Date', AppColors.auroraRose),
            const SizedBox(width: 6),
            _buildCategoryPill('🎮 Game', AppColors.auroraGold),
            const Spacer(),
            EverglowButton(
              label: 'Choose Tonight ✨',
              icon: Icons.auto_awesome_rounded,
              backgroundColor: AppColors.auroraRose,
              foregroundColor: AppColors.inkDeep,
              onPressed: () => context.push('/tonight'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVotingState(BuildContext context, TonightDecision decision) {
    final votesCount = decision.votes.length;
    final voteStatusText = votesCount == 0
        ? '3 picks ready · Tap to choose together!'
        : votesCount == 1
        ? '1 of 2 voted · Partner’s turn!'
        : decision.isTied
        ? 'Votes in · Tied! Let fate decide 🎲'
        : 'Both votes in!';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.auroraRose.withValues(alpha: 0.18),
                borderRadius: AppRadius.radiusFull,
                border: Border.all(
                  color: AppColors.auroraRose.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.touch_app_rounded,
                    color: AppColors.auroraRose,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    voteStatusText,
                    style: AppTypography.labelSmall().copyWith(
                      color: AppColors.auroraRose,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final opt in decision.options)
              _buildOptionSummaryPill(opt, decision),
          ],
        ),
      ],
    );
  }

  Widget _buildDecidedState(BuildContext context, TonightDecision decision) {
    final winner = decision.winningOption!;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.auroraGold.withValues(alpha: 0.15),
            border: Border.all(
              color: AppColors.auroraGold.withValues(alpha: 0.4),
            ),
          ),
          child: Center(
            child: Text(
              winner.type.emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Tonight’s Pick Decided! 🎉',
                    style: AppTypography.labelSmall().copyWith(
                      color: AppColors.auroraGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                winner.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall().copyWith(
                  color: AppColors.moonlight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        EverglowButton(
          label: 'Make Plan 📅',
          backgroundColor: AppColors.auroraGold,
          foregroundColor: AppColors.inkDeep,
          onPressed: () => context.push('/tonight'),
        ),
      ],
    );
  }

  Widget _buildPlannedState(BuildContext context, TonightDecision decision) {
    final winner = decision.winningOption!;
    final timeStr = decision.planTime != null
        ? DateFormat('h:mm a').format(decision.planTime!)
        : 'Tonight';

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.auroraTeal.withValues(alpha: 0.15),
            border: Border.all(
              color: AppColors.auroraTeal.withValues(alpha: 0.4),
            ),
          ),
          child: Center(
            child: Text(
              winner.type.emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tonight at $timeStr 🥂',
                style: AppTypography.labelSmall().copyWith(
                  color: AppColors.auroraTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                winner.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleSmall().copyWith(
                  color: AppColors.moonlight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (winner.targetRoute != null)
          EverglowButton(
            label: switch (winner.type) {
              TonightOptionType.movie => 'Watch 🎬',
              TonightOptionType.game => 'Play 🎮',
              TonightOptionType.date => 'Details 🌹',
            },
            backgroundColor: AppColors.auroraTeal,
            foregroundColor: AppColors.inkDeep,
            onPressed: () => context.push(winner.targetRoute!),
          ),
      ],
    );
  }

  Widget _buildCategoryPill(String label, Color hue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: hue.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall().copyWith(
          color: hue,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildOptionSummaryPill(
    TonightOption option,
    TonightDecision decision,
  ) {
    final votes = decision.votes.values.where((v) => v == option.id).length;
    final hue = switch (option.type) {
      TonightOptionType.movie => AppColors.auroraTeal,
      TonightOptionType.date => AppColors.auroraRose,
      TonightOptionType.game => AppColors.auroraGold,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: votes > 0 ? hue : AppColors.moonlight.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(option.type.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              option.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.moonlight,
                fontWeight: votes > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (votes > 0) ...[
            const SizedBox(width: 4),
            Text('💖' * votes, style: const TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }
}
