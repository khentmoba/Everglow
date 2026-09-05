import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_segmented_control.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../data/models/trip.dart';
import '../../data/services/travel_service.dart';
import '../widgets/add_trip_dialog.dart';
import '../widgets/travel_atlas_view.dart';

class TravelScreen extends StatefulWidget {
  const TravelScreen({super.key});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final service = TravelService();
    final auth = context.read<AuthService>();
        return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      glows: [const RadialGlow(color: AppColors.auroraTeal, alignment: Alignment(-0.6, -0.9), size: 0.85, opacity: 0.12)],
      body: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Atlas',
                  subtitle: 'where we\'ve been • Dawarich × AdventureLog',
                  icon: Icons.map_rounded,
                  hue: AppColors.auroraTeal,
                  actions: [
                    EverglowIconButton(
                      icon: Icons.add_location_alt_rounded,
                      onPressed: () => _showAddTrip(auth),
                      semanticLabel: '''New trip''',
                      tooltip: '''New trip''',
                      iconColor: AppColors.blushGold,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EverglowSegmentedControl(
                    selectedIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                    activeColor: AppColors.auroraTeal,
                    items: const [
                      SegmentItem('Trips', Icons.card_travel_rounded),
                      SegmentItem('Atlas', Icons.public_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _tabIndex == 1
                      ? const TravelAtlasView()
                      : EverglowStreamView<List<Trip>>(
                          stream: service.watchTrips(),
                          streamLabel: 'travel-trips',
                          errorMessage: 'Could not load trips',
                          errorIcon: Icons.map_rounded,
                          onRetry: () => setState(() {}),
                          isEmpty: (trips) => trips.isEmpty,
                          emptyView: EverglowEmptyState(
                            icon: Icons.map_rounded,
                            title: 'No trips yet',
                            subtitle:
                                'Plan your first getaway — pins, itinerary, auto-journal',
                            ctaLabel: 'New Trip',
                            onCta: () => _showAddTrip(auth),
                          ),
                          builder: (context, trips) => ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: trips.length,
                            itemBuilder: (context, idx) =>
                                _TripCard(trip: trips[idx]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTrip(auth),
        backgroundColor: AppColors.auroraTeal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddTrip(AuthService auth) {
    showDialog(
      context: context,
      builder: (_) => AddTripDialog(author: auth.currentUser ?? 'unknown'),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(trip.status);
    return GestureDetector(
      onTap: () => context.push('/travel/${trip.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.moonlight.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: Container(
                width: 90,
                height: 90,
                color: statusColor.withValues(alpha: 0.15),
                child: trip.coverUrl.isNotEmpty
                    ? Image.network(trip.coverUrl, fit: BoxFit.cover, errorBuilder: (_,_,_) => Center(child: Text(_statusEmoji(trip.status), style: const TextStyle(fontSize: 32))))
                    : Stack(
                        children: [
                          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [statusColor.withValues(alpha: 0.18), AppColors.inkDeep.withValues(alpha: 0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight)))),
                          Center(child: Text(_statusEmoji(trip.status), style: const TextStyle(fontSize: 32))),
                        ],
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trip.title,
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 14,
                              color: AppColors.petalWhite,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trip.status.name,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trip.description.isEmpty
                          ? 'No description'
                          : trip.description,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 11,
                        color: AppColors.petalWhite.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 10,
                          color: AppColors.petalWhite.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trip.startDate.month}/${trip.startDate.day} → ${trip.endDate.month}/${trip.endDate.day} • ${trip.days} days',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 10,
                            color: AppColors.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                        const Spacer(),
                        if (trip.budgetEstimate > 0)
                          Text(
                            '${trip.budgetEstimate.toStringAsFixed(0)} ${trip.currency}',
                            style: AppTypography.outfitBold.copyWith(
                              fontSize: 10,
                              color: AppColors.warmAmber,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.blushGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(TripStatus s) {
    switch (s) {
      case TripStatus.planning:
        return AppColors.softLavender;
      case TripStatus.upcoming:
        return AppColors.warmAmber;
      case TripStatus.active:
        return AppColors.auroraTeal;
      case TripStatus.completed:
        return AppColors.success;
    }
  }

  String _statusEmoji(TripStatus s) {
    switch (s) {
      case TripStatus.planning:
        return '🗺️';
      case TripStatus.upcoming:
        return '✈️';
      case TripStatus.active:
        return '📍';
      case TripStatus.completed:
        return '🏁';
    }
  }
}
