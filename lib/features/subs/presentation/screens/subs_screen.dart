import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/text_utils.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../data/models/subscription.dart';
import '../../data/services/subs_service.dart';
import '../widgets/add_sub_sheet.dart';
import '../widgets/sub_card.dart';

/// Subs Tracker — every shared subscription in one calm list.
///
/// A hero shows the monthly peso total so Khent + Clair can see where
/// money leaks, and each card counts down to its next renewal.
class SubsScreen extends StatelessWidget {
  const SubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SubsService();
    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      body: Column(
        children: [
          const EverglowFeatureHeader(
            title: 'Subscriptions',
            subtitle: 'where the money goes',
            icon: Icons.subscriptions_rounded,
            hue: AppColors.blushGold,
          ),
          Expanded(
            child: EverglowStreamView<List<Subscription>>(
              stream: service.watchAll(),
              streamLabel: 'subs',
              errorMessage: 'Could not load subscriptions',
              onRetry: () {},
              loadingView: const _LoadingSubs(),
              isEmpty: (_) => false,
              builder: (context, all) {
                final items = List<Subscription>.of(all)
                  ..sort(
                    (a, b) => a
                        .daysUntilRenewal()
                        .compareTo(b.daysUntilRenewal()),
                  );
                return Column(
                  children: [
                    _Constrained(child: SubsMoneyHero(all: all)),
                    const SizedBox(height: 4),
                    Expanded(child: _buildContent(context, all, items)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _TrackFab(
        onTap: () => _showAddSheet(context, null),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Subscription> all,
    List<Subscription> items,
  ) {
    if (all.isEmpty) {
      return EverglowEmptyState(
        icon: Icons.subscriptions_outlined,
        title: 'No subscriptions yet',
        subtitle: 'Track Netflix, Spotify, iCloud…',
        ctaLabel: 'Track one',
        onCta: () => _showAddSheet(context, null),
      );
    }
    return _Constrained(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: items.length,
        itemBuilder: (context, index) => SubCard(
          key: ValueKey(items[index].id),
          sub: items[index],
          onTap: () => _showAddSheet(context, items[index]),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, Subscription? existing) {
    final auth = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddSubSheet(
        createdBy: auth.currentUser ?? 'unknown',
        existing: existing,
      ),
    );
  }
}

/// Centers [child] and caps its width on tablets / desktop.
class _Constrained extends StatelessWidget {
  final Widget child;
  const _Constrained({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
  }
}

/// Monthly peso total + soonest renewal, so the leak is visible at a glance.
class SubsMoneyHero extends StatelessWidget {
  final List<Subscription> all;
  const SubsMoneyHero({super.key, required this.all});

  @override
  Widget build(BuildContext context) {
    final monthly =
        all.fold<double>(0, (sum, s) => sum + s.monthlyCost);
    final soonest = all.isEmpty
        ? null
        : all.reduce(
            (a, b) =>
                a.daysUntilRenewal() <= b.daysUntilRenewal() ? a : b,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.silk, AppColors.velvet, AppColors.inkDeep],
            stops: [0.0, 0.45, 1.0],
          ),
          borderRadius: AppRadius.radiusX2,
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💸  EVERY MONTH',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 10,
                letterSpacing: 1.6,
                color: AppColors.blushGold.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatPeso(monthly.round()),
              style: AppTypography.cormorantBold.copyWith(
                fontSize: 38,
                height: 1.0,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle(all.length, soonest),
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 12,
                color: AppColors.petalWhite.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(int count, Subscription? soonest) {
    if (count == 0) return 'Nothing tracked yet — add your first sub below';
    final noun = count == 1 ? 'subscription' : 'subscriptions';
    if (soonest == null) return 'across $count $noun';
    final days = soonest.daysUntilRenewal();
    final when = days <= 0
        ? 'renews today'
        : days == 1
            ? 'renews tomorrow'
            : 'renews in $days days';
    return 'across $count $noun · ${soonest.name} $when';
  }
}

/// Extended gradient "Track" button.
class _TrackFab extends StatelessWidget {
  final VoidCallback onTap;
  const _TrackFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Track a new subscription',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepRose, AppColors.rosePressed],
            ),
            borderRadius: AppRadius.radiusFull,
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.glowRose,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.petalWhite,
              ),
              const SizedBox(width: 6),
              Text(
                'Track',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 14,
                  color: AppColors.petalWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading shimmer shaped like the hero + cards.
class _LoadingSubs extends StatelessWidget {
  const _LoadingSubs();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: const [
        EverglowSkeleton(width: double.infinity, height: 150, radius: 24),
        SizedBox(height: 12),
        EverglowSkeleton(width: double.infinity, height: 76, radius: 20),
        SizedBox(height: 10),
        EverglowSkeleton(width: double.infinity, height: 76, radius: 20),
        SizedBox(height: 10),
        EverglowSkeleton(width: double.infinity, height: 76, radius: 20),
      ],
    );
  }
}
