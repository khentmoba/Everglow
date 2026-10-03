import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
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
                  subtitle: 'An evening for two',
                  hue: AppColors.auroraRose,
                  actions: [
                    IconButton(
                      tooltip: _isShuffling
                          ? 'Finding new picks…'
                          : 'Shuffle picks',
                      icon: _isShuffling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.shuffle_rounded,
                              color: AppColors.roseQuartz,
                            ),
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
              if (decision.status == TonightStatus.voting) ...[
                Text(
                  'JUST US, TONIGHT',
                  style: AppTypography.labelSmall().copyWith(
                    color: AppColors.blushGold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'A little time for us.',
                  style: AppTypography.displaySmall().copyWith(
                    color: AppColors.petalWhite,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'A movie, a date, or a little friendly competition.',
                  style: AppTypography.bodyMedium(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _buildLiveStatusBar(decision, currentUsername, partnerName),
              const SizedBox(height: AppSpacing.lg),
              if (decision.status != TonightStatus.voting &&
                  decision.winningOption != null)
                _TonightOptionCard(
                  option: decision.winningOption!,
                  decision: decision,
                  currentUsername: currentUsername,
                  compact: true,
                  onVote: _handleVote,
                  onDecideDirectly: _handleDecideDirectly,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth >= 840
                      ? _buildCardsRow(decision, currentUsername)
                      : _buildCardsColumn(decision, currentUsername),
                ),
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

    String title;
    String detail;
    IconData icon = Icons.favorite_outline_rounded;
    Color hue = AppColors.roseQuartz;
    Widget? action;

    if (decision.status == TonightStatus.planned) {
      title = 'Our evening is set.';
      detail = decision.planTime == null
          ? 'Something lovely to look forward to.'
          : 'Tonight at ${DateFormat('h:mm a').format(decision.planTime!)} · Saved to our calendar';
      icon = Icons.check_circle_outline_rounded;
      hue = AppColors.auroraTeal;
    } else if (decision.status == TonightStatus.decided) {
      title = decision.isMatch ? 'It’s a match.' : 'Tonight, we’re doing this.';
      detail = decision.isMatch
          ? 'Different hearts. The same little wish.'
          : 'One lovely choice for the two of us.';
      icon = Icons.favorite_rounded;
    } else if (decision.isTied) {
      title = 'Two picks, one evening.';
      detail = 'Choose one together below, or leave it to chance.';
      icon = Icons.shuffle_rounded;
      hue = AppColors.blushGold;
      action = EverglowButton.glass(
        label: 'Flip a coin',
        icon: Icons.shuffle_rounded,
        foregroundColor: hue,
        onPressed: () => _handleFlipCoin(decision),
      );
    } else if (userVote != null && partnerVote == null) {
      title = 'Your little wish is in.';
      detail = 'Waiting for $partnerName. You can still change your pick.';
      icon = Icons.hourglass_top_rounded;
    } else if (userVote == null && partnerVote != null) {
      title = '$partnerName has a pick.';
      detail = 'Your turn. Choose what sounds lovely tonight.';
    } else {
      title = 'What are we in the mood for?';
      detail = 'Pick your favorite. Choose the same one and it’s a match.';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [hue.withValues(alpha: 0.10), AppColors.panelGlass],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: hue.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: hue, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium().copyWith(
                        color: AppColors.petalWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      detail,
                      style: AppTypography.bodySmall().copyWith(
                        color: AppColors.textMedium,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildCardsRow(TonightDecision decision, String currentUsername) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
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
            compact: true,
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
      fillColor: AppColors.roseQuartz.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.roseQuartz,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Save a little time for us',
                  style: AppTypography.headlineSmall().copyWith(
                    color: AppColors.petalWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose a time for ${option.title}. We’ll save it to our shared calendar.',
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.moonlight.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Tonight at',
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
                  showCheckmark: false,
                  selectedColor: AppColors.roseQuartz,
                  backgroundColor: AppColors.panelGlass,
                  side: BorderSide(color: AppColors.border),
                  labelStyle: AppTypography.bodySmall().copyWith(
                    color:
                        _selectedPlanTime.hour == time.hour &&
                            _selectedPlanTime.minute == time.minute
                        ? AppColors.inkDeep
                        : AppColors.textMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          EverglowButton(
            label: _isMakingPlan ? 'Adding to Calendar...' : 'Save our plan',
            icon: Icons.check_circle_rounded,
            backgroundColor: AppColors.roseQuartz,
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
                      'See you at $timeStr',
                      style: AppTypography.headlineSmall().copyWith(
                        color: AppColors.moonlight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      winningOption.title,
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
                    TonightOptionType.movie => 'Open Cinema',
                    TonightOptionType.game => 'Play together',
                    TonightOptionType.date => 'View Calendar',
                  },
                  icon: Icons.play_arrow_rounded,
                  backgroundColor: AppColors.auroraTeal,
                  foregroundColor: AppColors.inkDeep,
                  onPressed: () => context.push(winningOption.targetRoute!),
                ),
              if (winningOption.targetRoute != '/calendar')
                EverglowButton.glass(
                  label: 'View in Calendar',
                  icon: Icons.calendar_month_rounded,
                  foregroundColor: AppColors.moonlight,
                  onPressed: () => context.push('/calendar'),
                ),
              EverglowButton.glass(
                label: 'New picks',
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
  final bool compact;
  final ValueChanged<String> onVote;
  final ValueChanged<String> onDecideDirectly;

  const _TonightOptionCard({
    required this.option,
    required this.decision,
    required this.currentUsername,
    this.compact = false,
    required this.onVote,
    required this.onDecideDirectly,
  });

  @override
  Widget build(BuildContext context) {
    final isWinner = decision.winnerOptionId == option.id;
    final selected = decision.votes[currentUsername] == option.id;
    final canChoose = decision.status == TonightStatus.voting;
    final hue = switch (option.type) {
      TonightOptionType.movie => AppColors.auroraLilac,
      TonightOptionType.date => AppColors.roseQuartz,
      TonightOptionType.game => AppColors.blushGold,
    };
    final voters = [
      if (decision.khentVote == option.id) 'Khent',
      if (decision.clairVote == option.id) 'Clair',
    ];
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isWinner
              ? 'OUR PICK · ${option.type.label.toUpperCase()}'
              : option.type.label.toUpperCase(),
          style: AppTypography.labelSmall().copyWith(
            color: hue,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          option.title,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium().copyWith(
            color: AppColors.petalWhite,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        if (option.subtitle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            option.subtitle,
            style: AppTypography.bodySmall().copyWith(color: hue),
          ),
        ],
        if (option.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            option.description,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall().copyWith(
              color: AppColors.textMedium,
              height: 1.4,
            ),
          ),
        ],
        if (voters.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 12, color: hue),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${voters.join(' + ')}’s pick',
                  style: AppTypography.labelSmall().copyWith(color: hue),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final pickButton = EverglowButton(
      label: selected ? 'Your pick' : 'Pick this',
      icon: selected ? Icons.check_rounded : null,
      backgroundColor: selected ? hue : hue.withValues(alpha: 0.12),
      foregroundColor: selected ? AppColors.inkDeep : hue,
      onPressed: () => onVote(option.id),
    );
    final togetherButton = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMedium,
        minimumSize: const Size(48, 48),
        textStyle: AppTypography.bodySmall(),
      ),
      onPressed: () => onDecideDirectly(option.id),
      child: const Text('Choose together'),
    );
    final stackActions =
        !compact || MediaQuery.textScalerOf(context).scale(14) > 18;

    return Semantics(
      selected: selected,
      child: EverglowCard(
        padding: EdgeInsets.zero,
        radius: AppRadius.x2,
        fillColor: AppColors.inkDeep,
        semanticLabel: '${option.type.label}: ${option.title}',
        onTap: canChoose ? () => onVote(option.id) : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(
              colors: [
                hue.withValues(alpha: isWinner || selected ? 0.14 : 0.07),
                AppColors.panelGlass,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isWinner || selected
                  ? hue.withValues(alpha: 0.7)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 76, height: 114, child: _buildVisual(hue)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: details),
                  ],
                )
              else ...[
                SizedBox(height: 144, child: _buildVisual(hue)),
                const SizedBox(height: AppSpacing.md),
                details,
              ],
              if (canChoose) ...[
                if (!compact) const Spacer(),
                const SizedBox(height: AppSpacing.md),
                if (stackActions)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [pickButton, togetherButton],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: pickButton),
                      const SizedBox(width: AppSpacing.sm),
                      togetherButton,
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisual(Color hue) {
    final icon = switch (option.type) {
      TonightOptionType.movie => Icons.movie_outlined,
      TonightOptionType.date => Icons.favorite_border_rounded,
      TonightOptionType.game => Icons.sports_esports_outlined,
    };
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [hue.withValues(alpha: 0.16), AppColors.silk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -18,
            bottom: -18,
            child: Icon(icon, size: 100, color: hue.withValues(alpha: 0.06)),
          ),
          Icon(icon, size: compact ? 30 : 48, color: hue),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: AppRadius.radiusLg,
      child: option.imageUrl?.isNotEmpty == true
          ? Container(
              color: AppColors.silk,
              child: Image.network(
                option.imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => placeholder,
              ),
            )
          : placeholder,
    );
  }
}
