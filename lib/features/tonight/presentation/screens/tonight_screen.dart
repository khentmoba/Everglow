import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_button.dart';
import '../../../../shared/widgets/everglow/everglow_card.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../data/models/tonight_decision.dart';
import '../../data/models/tonight_option.dart';
import '../../data/services/tonight_service.dart';

class TonightScreen extends StatefulWidget {
  final TonightDecision? previewDecision;
  const TonightScreen({super.key, this.previewDecision});

  @override
  State<TonightScreen> createState() => _TonightScreenState();
}

class _TonightScreenState extends State<TonightScreen> {
  final TonightService _service = TonightService();
  bool _isShuffling = false;
  bool _isMakingPlan = false;
  DateTime _selectedPlanTime = _defaultPlanTime();

  static DateTime _defaultPlanTime() {
    final now = DateTime.now();
    if (now.hour >= 20) {
      return DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    }
    return DateTime(now.year, now.month, now.day, 20, 0);
  }

  Future<void> _handleShuffle() async {
    setState(() => _isShuffling = true);
    await _service.createOrShuffle(force: true);
    if (mounted) setState(() => _isShuffling = false);
  }

  Future<void> _handleVote(String optionId) async {
    final auth = context.read<AuthService>();
    final username = auth.currentUser;
    if (username == null || username.isEmpty) return;

    await _service.castVote(username: username, optionId: optionId);
  }

  Future<void> _handleDecideDirectly(String optionId) async {
    await _service.decideWinner(optionId: optionId);
  }

  Future<void> _handleFlipCoin(TonightDecision decision) async {
    final khentOpt = decision.khentVote;
    final clairOpt = decision.clairVote;
    if (khentOpt == null || clairOpt == null) return;

    final choices = [khentOpt, clairOpt];
    final winner = choices[Random().nextInt(choices.length)];

    await _service.decideWinner(optionId: winner);
  }

  Future<void> _handleMakePlan(TonightOption winningOption) async {
    final auth = context.read<AuthService>();
    final username = auth.currentUser ?? 'khentsgdz';

    setState(() => _isMakingPlan = true);
    final event = await _service.makePlan(
      option: winningOption,
      planTime: _selectedPlanTime,
      createdBy: username,
    );
    if (mounted) {
      setState(() => _isMakingPlan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.velvet,
          content: Text(
            event != null
                ? 'Tonight’s plan added to your Calendar! 📅✨'
                : 'Couldn’t save the plan. Please try again.',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.moonlight,
            ),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final currentUsername = auth.currentUser ?? 'khentsgdz';
    final partnerName = auth.partnerName;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraRose,
                  alignment: Alignment(-0.85, -0.75),
                  size: 0.9,
                  opacity: 0.14,
                ),
                RadialGlow(
                  color: AppColors.auroraGold,
                  alignment: Alignment(0.85, -0.4),
                  size: 0.85,
                  opacity: 0.12,
                ),
                RadialGlow(
                  color: AppColors.auroraTeal,
                  alignment: Alignment(0.0, 0.9),
                  size: 0.8,
                  opacity: 0.10,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Tonight',
                  subtitle: '“What should we do?” · 3 picks for two',
                  icon: Icons.nightlife_rounded,
                  hue: AppColors.auroraRose,
                  actions: [
                    EverglowButton.glass(
                      label: _isShuffling ? 'Rolling...' : 'Shuffle',
                      icon: Icons.casino_rounded,
                      onPressed: _isShuffling ? null : _handleShuffle,
                    ),
                  ],
                ),
                Expanded(
                  child: StreamBuilder<TonightDecision?>(
                    initialData: widget.previewDecision,
                    stream: widget.previewDecision != null
                        ? Stream.value(widget.previewDecision)
                        : _service.watchActiveDecision(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return _buildLoadingSkeleton();
                      }

                      final decision = snapshot.data;
                      if (decision == null || decision.options.isEmpty) {
                        return _buildEmptyOrBootstrapView();
                      }

                      return _buildDecisionContent(
                        context: context,
                        decision: decision,
                        currentUsername: currentUsername,
                        partnerName: partnerName,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EverglowSkeleton(height: 60, width: double.infinity),
              SizedBox(height: AppSpacing.lg),
              EverglowSkeleton(height: 220, width: double.infinity),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrBootstrapView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.auroraRose.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.auroraRose.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.auroraRose,
                  size: 36,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '“What should we do tonight?”',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSmall().copyWith(
                  color: AppColors.moonlight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Roll 3 curated suggestions for tonight from your watchlist, date ideas, and games.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium().copyWith(
                  color: AppColors.moonlight.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              EverglowButton(
                label: 'Roll Suggestions',
                icon: Icons.casino_rounded,
                backgroundColor: AppColors.auroraRose,
                foregroundColor: AppColors.inkDeep,
                onPressed: _handleShuffle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDecisionContent({
    required BuildContext context,
    required TonightDecision decision,
    required String currentUsername,
    required String partnerName,
  }) {
    final isDesktopOrTablet = !AppBreakpoint.isMobile(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageH(context),
        AppSpacing.md,
        AppSpacing.pageH(context),
        AppSpacing.x3,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLiveStatusBar(decision, currentUsername, partnerName),
              const SizedBox(height: AppSpacing.lg),
              if (isDesktopOrTablet)
                _buildCardsRow(decision, currentUsername)
              else
                _buildCardsColumn(decision, currentUsername),
              const SizedBox(height: AppSpacing.xl),
              if (decision.status == TonightStatus.decided &&
                  decision.winningOption != null)
                _buildMakePlanSection(decision.winningOption!)
              else if (decision.status == TonightStatus.planned &&
                  decision.winningOption != null)
                _buildPlanSuccessSection(decision),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusBar(
    TonightDecision decision,
    String currentUsername,
    String partnerName,
  ) {
    final userVote = decision.votes[currentUsername];
    final partnerVote = decision
        .votes[currentUsername == 'khentsgdz' ? 'clairjassen' : 'khentsgdz'];

    String statusText;
    IconData statusIcon = Icons.stars_rounded;
    Color statusHue = AppColors.auroraGold;
    Widget? trailingAction;

    if (decision.status == TonightStatus.planned) {
      final timeStr = decision.planTime != null
          ? DateFormat('h:mm a').format(decision.planTime!)
          : 'Tonight';
      statusText = 'Plan is set for $timeStr! 🥂';
      statusIcon = Icons.celebration_rounded;
      statusHue = AppColors.auroraTeal;
    } else if (decision.status == TonightStatus.decided) {
      statusText = decision.isMatch
          ? 'It’s a Match! You both chose ${decision.winningOption?.title ?? "this"}! 🎉'
          : 'Tonight’s Choice: ${decision.winningOption?.title ?? "Winner chosen"} ✨';
      statusIcon = Icons.favorite_rounded;
      statusHue = AppColors.auroraRose;
    } else if (decision.isTied) {
      statusText = 'You voted differently! Flip a coin or agree together:';
      statusIcon = Icons.compare_arrows_rounded;
      statusHue = AppColors.warmAmber;
      trailingAction = EverglowButton.glass(
        label: 'Let Fate Decide 🎲',
        icon: Icons.shuffle_rounded,
        foregroundColor: AppColors.blushGold,
        onPressed: () => _handleFlipCoin(decision),
      );
    } else if (userVote != null && partnerVote == null) {
      statusText = 'Your vote is in! Waiting for $partnerName to choose... 💖';
      statusIcon = Icons.hourglass_top_rounded;
      statusHue = AppColors.auroraRose;
    } else if (userVote == null && partnerVote != null) {
      statusText =
          '$partnerName voted! Tap your pick below to decide together ✨';
      statusIcon = Icons.mark_chat_unread_rounded;
      statusHue = AppColors.auroraGold;
    } else {
      statusText = 'Tap an activity below to cast your vote! First match wins.';
      statusIcon = Icons.touch_app_rounded;
      statusHue = AppColors.auroraRose;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: statusHue.withValues(alpha: 0.10),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: statusHue.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusHue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: AppTypography.bodyMedium().copyWith(
                color: AppColors.moonlight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailingAction != null) ...[
            const SizedBox(width: 8),
            trailingAction,
          ],
        ],
      ),
    );
  }

  Widget _buildCardsRow(TonightDecision decision, String currentUsername) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < decision.options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _TonightOptionCard(
              option: decision.options[i],
              decision: decision,
              currentUsername: currentUsername,
              onVote: _handleVote,
              onDecideDirectly: (optId) => _handleDecideDirectly(optId),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardsColumn(TonightDecision decision, String currentUsername) {
    return Column(
      children: [
        for (final opt in decision.options) ...[
          _TonightOptionCard(
            option: opt,
            decision: decision,
            currentUsername: currentUsername,
            onVote: _handleVote,
            onDecideDirectly: (optId) => _handleDecideDirectly(optId),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _buildMakePlanSection(TonightOption option) {
    final timeSlots = [
      _buildSlotTime(19, 0),
      _buildSlotTime(20, 0),
      _buildSlotTime(21, 0),
      _buildSlotTime(22, 0),
    ];

    return EverglowCard(
      fillColor: AppColors.auroraRose.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.auroraRose,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Make it Tonight’s Plan',
                style: AppTypography.headlineSmall().copyWith(
                  color: AppColors.moonlight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Lock in ${option.title} to your shared calendar so neither of you forgets.',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.moonlight.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Select time:',
            style: AppTypography.labelSmall().copyWith(
              color: AppColors.moonlight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final time in timeSlots)
                ChoiceChip(
                  label: Text(DateFormat('h:mm a').format(time)),
                  selected:
                      _selectedPlanTime.hour == time.hour &&
                      _selectedPlanTime.minute == time.minute,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedPlanTime = time);
                  },
                  selectedColor: AppColors.auroraRose.withValues(alpha: 0.35),
                  backgroundColor: AppColors.surfaceGlass,
                  labelStyle: AppTypography.bodySmall().copyWith(
                    color: AppColors.moonlight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          EverglowButton(
            label: _isMakingPlan
                ? 'Adding to Calendar...'
                : 'Confirm Plan & Add to Calendar 📅',
            icon: Icons.check_circle_rounded,
            backgroundColor: AppColors.auroraRose,
            foregroundColor: AppColors.inkDeep,
            onPressed: _isMakingPlan ? null : () => _handleMakePlan(option),
          ),
        ],
      ),
    );
  }

  DateTime _buildSlotTime(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  Widget _buildPlanSuccessSection(TonightDecision decision) {
    final winningOption = decision.winningOption;
    if (winningOption == null) return const SizedBox.shrink();

    final timeStr = decision.planTime != null
        ? DateFormat('h:mm a').format(decision.planTime!)
        : 'Tonight';

    return EverglowCard(
      fillColor: AppColors.auroraTeal.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.celebration_rounded,
                color: AppColors.auroraTeal,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Planned for $timeStr!',
                      style: AppTypography.headlineSmall().copyWith(
                        color: AppColors.moonlight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${winningOption.type.emoji} ${winningOption.title}',
                      style: AppTypography.bodyMedium().copyWith(
                        color: AppColors.auroraTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (winningOption.targetRoute != null)
                EverglowButton(
                  label: switch (winningOption.type) {
                    TonightOptionType.movie => 'Open Cinema 🎬',
                    TonightOptionType.game => 'Play Now 🎮',
                    TonightOptionType.date => 'View Calendar 📅',
                  },
                  icon: Icons.play_arrow_rounded,
                  backgroundColor: AppColors.auroraTeal,
                  foregroundColor: AppColors.inkDeep,
                  onPressed: () => context.push(winningOption.targetRoute!),
                ),
              EverglowButton.glass(
                label: 'View in Calendar 📅',
                icon: Icons.calendar_month_rounded,
                foregroundColor: AppColors.moonlight,
                onPressed: () => context.push('/calendar'),
              ),
              EverglowButton.glass(
                label: 'Plan Another Tonight 🔄',
                icon: Icons.refresh_rounded,
                foregroundColor: AppColors.blushGold,
                onPressed: _handleShuffle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TonightOptionCard extends StatelessWidget {
  final TonightOption option;
  final TonightDecision decision;
  final String currentUsername;
  final ValueChanged<String> onVote;
  final ValueChanged<String> onDecideDirectly;

  const _TonightOptionCard({
    required this.option,
    required this.decision,
    required this.currentUsername,
    required this.onVote,
    required this.onDecideDirectly,
  });

  @override
  Widget build(BuildContext context) {
    final isWinner = decision.winnerOptionId == option.id;
    final isPlanned = decision.status == TonightStatus.planned && isWinner;
    final userVotedForThis = decision.votes[currentUsername] == option.id;
    final khentVoted = decision.votes['khentsgdz'] == option.id;
    final clairVoted = decision.votes['clairjassen'] == option.id;

    final typeHue = switch (option.type) {
      TonightOptionType.movie => AppColors.auroraTeal,
      TonightOptionType.date => AppColors.auroraRose,
      TonightOptionType.game => AppColors.auroraGold,
    };

    final cardBorderColor = isWinner
        ? AppColors.auroraGold
        : userVotedForThis
        ? typeHue
        : AppColors.moonlight.withValues(alpha: 0.12);

    final cardGlowColor = isWinner
        ? AppColors.auroraGold.withValues(alpha: 0.22)
        : userVotedForThis
        ? typeHue.withValues(alpha: 0.15)
        : Colors.transparent;

    return Semantics(
      button: true,
      label: '${option.type.label}: ${option.title}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusXl,
          boxShadow: [
            if (isWinner || userVotedForThis)
              BoxShadow(color: cardGlowColor, blurRadius: 18, spreadRadius: 2),
          ],
        ),
        child: EverglowCard(
          padding: EdgeInsets.zero,
          radius: AppRadius.x3,
          fillColor: isWinner
              ? AppColors.auroraGold.withValues(alpha: 0.08)
              : AppColors.surfaceGlass,
          onTap: decision.status == TonightStatus.voting
              ? () => onVote(option.id)
              : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusXl,
              border: Border.all(
                color: cardBorderColor,
                width: isWinner
                    ? 2.2
                    : userVotedForThis
                    ? 1.8
                    : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardHeader(typeHue, isWinner),
                _buildCardVisual(typeHue),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium().copyWith(
                          color: AppColors.moonlight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (option.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.subtitle,
                          style: AppTypography.labelSmall().copyWith(
                            color: typeHue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        option.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall().copyWith(
                          color: AppColors.moonlight.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildVoteStatusBadges(khentVoted, clairVoted),
                      const SizedBox(height: AppSpacing.sm),
                      _buildActionButtons(
                        userVotedForThis,
                        isPlanned,
                        decision.status == TonightStatus.voting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(Color typeHue, bool isWinner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: typeHue.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.x2),
        ),
      ),
      child: Row(
        children: [
          Text(option.type.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            option.type.label.toUpperCase(),
            style: AppTypography.labelSmall().copyWith(
              color: typeHue,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          if (isWinner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.auroraGold,
                borderRadius: AppRadius.radiusSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AppColors.inkDeep,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'WINNER',
                    style: AppTypography.labelSmall().copyWith(
                      color: AppColors.inkDeep,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardVisual(Color typeHue) {
    if (option.imageUrl != null && option.imageUrl!.isNotEmpty) {
      return SizedBox(
        height: 140,
        width: double.infinity,
        child: Image.network(
          option.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildVisualPlaceholder(typeHue),
        ),
      );
    }
    return _buildVisualPlaceholder(typeHue);
  }

  Widget _buildVisualPlaceholder(Color typeHue) {
    return Container(
      height: 110,
      color: typeHue.withValues(alpha: 0.05),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: typeHue.withValues(alpha: 0.14),
          ),
          child: Icon(
            switch (option.type) {
              TonightOptionType.movie => Icons.movie_filter_rounded,
              TonightOptionType.date => Icons.favorite_rounded,
              TonightOptionType.game => Icons.sports_esports_rounded,
            },
            color: typeHue,
            size: 34,
          ),
        ),
      ),
    );
  }

  Widget _buildVoteStatusBadges(bool khentVoted, bool clairVoted) {
    if (!khentVoted && !clairVoted) {
      return const SizedBox(height: 22);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (khentVoted)
          _buildChip(
            label: 'Khent’s Pick',
            icon: Icons.favorite_rounded,
            hue: AppColors.auroraRose,
          ),
        if (clairVoted)
          _buildChip(
            label: 'Clair’s Pick',
            icon: Icons.favorite_rounded,
            hue: AppColors.auroraGold,
          ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required Color hue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.20),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: hue.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: hue),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall().copyWith(
              color: AppColors.moonlight,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    bool userVotedForThis,
    bool isPlanned,
    bool canChoose,
  ) {
    if (isPlanned || !canChoose) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: EverglowButton(
            label: userVotedForThis ? 'Voted' : 'Vote',
            icon: userVotedForThis ? null : Icons.how_to_vote_rounded,
            backgroundColor: userVotedForThis
                ? AppColors.auroraRose
                : AppColors.surfaceGlass,
            foregroundColor: userVotedForThis
                ? AppColors.inkDeep
                : AppColors.moonlight,
            onPressed: () => onVote(option.id),
          ),
        ),
        const SizedBox(width: 6),
        EverglowButton.glass(
          label: 'Decide',
          tooltip: 'Pick this together right now',
          icon: Icons.check_circle_outline_rounded,
          foregroundColor: AppColors.blushGold,
          onPressed: () => onDecideDirectly(option.id),
        ),
      ],
    );
  }
}
