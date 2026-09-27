import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../data/models/trip.dart';
import '../../data/services/trip_kit_service.dart';
import '../widgets/trip_ui.dart';

/// Trip Kit — every lakad on one card: packing + budget + places.
class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

const double _kMaxContentWidth = 720;

class _TripListScreenState extends State<TripListScreen> {
  @override
  Widget build(BuildContext context) {
    final service = TripKitService();

    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      body: Column(
        children: [
          const EverglowFeatureHeader(
            title: 'Trip Kit',
            subtitle: 'every lakad, one page',
            icon: Icons.luggage_rounded,
            hue: AppColors.auroraTeal,
          ),
          Expanded(
            child: EverglowStreamView<List<Trip>>(
              stream: service.watchAll(),
              streamLabel: 'trip-kit-list',
              errorMessage: 'Could not load trips',
              onRetry: () => setState(() {}),
              loadingView: const _LoadingTrips(),
              isEmpty: (trips) => trips.isEmpty,
              emptyView: EverglowEmptyState(
                icon: Icons.luggage_outlined,
                title: 'No trips yet',
                subtitle: 'Plan your first lakad together',
                ctaLabel: 'Plan a trip',
                onCta: () => _showCreateSheet(context),
              ),
              builder: (context, trips) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kMaxContentWidth,
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: trips.length,
                      itemBuilder: (context, index) =>
                          TripCard(trip: trips[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _NewTripFab(
        onTap: () => _showCreateSheet(context),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    final auth = context.read<AuthService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _TripEditSheet(createdBy: auth.currentUser ?? 'unknown'),
    );
  }
}

// ── Trip card ─────────────────────────────────────────────────

class TripCard extends StatelessWidget {
  final Trip trip;
  const TripCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final where = trip.destination.isEmpty ? 'Somewhere' : trip.destination;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: 'Open trip ${trip.title}',
        child: GestureDetector(
          onTap: () => context.push('/trips/${trip.id}'),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.silk, AppColors.velvet],
              ),
              borderRadius: AppRadius.radiusX2,
              border: Border.all(
                color: AppColors.auroraTeal.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.auroraTeal.withValues(alpha: 0.14),
                        border: Border.all(
                          color: AppColors.auroraTeal.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.luggage_rounded,
                        size: 20,
                        color: AppColors.auroraTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.title.isEmpty ? 'Untitled trip' : trip.title,
                            style: AppTypography.cormorantBold.copyWith(
                              fontSize: 21,
                              height: 1.1,
                              color: AppColors.petalWhite,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$where · ${tripDateRange(trip)}',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              color: AppColors.petalWhite.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.petalWhite.withValues(alpha: 0.35),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _miniStat(
                      Icons.backpack_rounded,
                      '${trip.packedCount}/${trip.packing.length} packed',
                      AppColors.warmAmber,
                    ),
                    const SizedBox(width: 8),
                    _miniStat(
                      Icons.wallet_rounded,
                      trip.budgetTotal > 0
                          ? '${tripPeso(trip.spentTotal)} of ${tripPeso(trip.budgetTotal)}'
                          : '${tripPeso(trip.spentTotal)} spent',
                      trip.overBudget
                          ? AppColors.error
                          : AppColors.auroraTeal,
                    ),
                    const SizedBox(width: 8),
                    _miniStat(
                      Icons.place_rounded,
                      '${trip.visitedCount}/${trip.places.length} places',
                      AppColors.auroraRose,
                    ),
                  ],
                ),
                if (trip.budgetTotal > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: AppRadius.radiusFull,
                    child: LinearProgressIndicator(
                      value: trip.budgetProgress,
                      minHeight: 6,
                      backgroundColor: AppColors.moonlight.withValues(
                        alpha: 0.10,
                      ),
                      valueColor: AlwaysStoppedAnimation(
                        trip.overBudget
                            ? AppColors.error
                            : AppColors.auroraTeal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String text, Color hue) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.10),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: hue.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: hue),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 10.5,
                  color: hue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create / edit sheet ───────────────────────────────────────

/// Bottom sheet for a new trip — or editing details of [trip].
class _TripEditSheet extends StatefulWidget {
  final String createdBy;
  final Trip? trip;
  const _TripEditSheet({required this.createdBy, this.trip});

  @override
  State<_TripEditSheet> createState() => _TripEditSheetState();
}

class _TripEditSheetState extends State<_TripEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _destination;
  late final TextEditingController _notes;
  late final TextEditingController _budget;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    _title = TextEditingController(text: t?.title ?? '');
    _destination = TextEditingController(text: t?.destination ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _budget = TextEditingController(
      text: t != null && t.budgetTotal > 0
          ? t.budgetTotal.toStringAsFixed(t.budgetTotal % 1 == 0 ? 0 : 2)
          : '',
    );
    _start = t?.startDate;
    _end = t?.endDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _destination.dispose();
    _notes.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.trip != null;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: insets),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.velvet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.25),
                  borderRadius: AppRadius.radiusFull,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              editing ? 'Edit trip' : 'New trip',
              style: AppTypography.cormorantBold.copyWith(
                fontSize: 24,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 14),
            _field(_title, 'Trip name (e.g. Tagaytay weekend)'),
            const SizedBox(height: 10),
            _field(_destination, 'Destination (e.g. Tagaytay)'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _dateChip('Start', _start, (d) {
                  setState(() => _start = d);
                })),
                const SizedBox(width: 8),
                Expanded(child: _dateChip('End', _end, (d) {
                  setState(() => _end = d);
                })),
              ],
            ),
            const SizedBox(height: 10),
            _field(
              _budget,
              'Budget in ₱ (optional)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            _field(_notes, 'Notes (optional)', maxLines: 2),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.deepRose, AppColors.rosePressed],
                  ),
                  borderRadius: AppRadius.radiusFull,
                ),
                child: Text(
                  editing ? 'Save changes' : 'Create trip',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 15,
                    color: AppColors.petalWhite,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.06),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.12),
        ),
      ),
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: AppTypography.outfitWhite.copyWith(fontSize: 14),
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: AppTypography.outfitWhite.copyWith(
            fontSize: 14,
            color: AppColors.petalWhite.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  Widget _dateChip(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onPick,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.moonlight.withValues(alpha: 0.06),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: AppColors.auroraTeal.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null ? label : DateFormat.MMMd().format(value),
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 13,
                  color: value == null
                      ? AppColors.petalWhite.withValues(alpha: 0.35)
                      : AppColors.petalWhite,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onPick(null),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.petalWhite.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final service = TripKitService();
    final budget = double.tryParse(_budget.text.trim()) ?? 0.0;
    final existing = widget.trip;
    if (existing == null) {
      final id = await service.create(
        Trip(
          id: '',
          title: title,
          destination: _destination.text.trim(),
          startDate: _start,
          endDate: _end,
          notes: _notes.text.trim(),
          budgetTotal: budget < 0 ? 0 : budget,
          createdBy: widget.createdBy,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (id != null && mounted) context.push('/trips/$id');
    } else {
      await service.updateDetails(
        existing.copyWith(
          title: title,
          destination: _destination.text.trim(),
          notes: _notes.text.trim(),
          budgetTotal: budget < 0 ? 0 : budget,
          clearStartDate: _start == null,
          clearEndDate: _end == null,
          // copyWith only overrides non-null, so apply dates explicitly.
          startDate: _start ?? existing.startDate,
          endDate: _end ?? existing.endDate,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    }
  }
}

/// Shared with the detail screen's edit button.
void showTripEditSheet(BuildContext context, Trip trip) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _TripEditSheet(
      createdBy: trip.createdBy,
      trip: trip,
    ),
  );
}

// ── FAB + loading ─────────────────────────────────────────────

class _NewTripFab extends StatelessWidget {
  final VoidCallback onTap;
  const _NewTripFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Plan a new trip',
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
                color: AppColors.deepRose.withValues(alpha: 0.35),
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
                'New trip',
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

class _LoadingTrips extends StatelessWidget {
  const _LoadingTrips();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: const [
        EverglowSkeleton(width: double.infinity, height: 170, radius: 24),
        SizedBox(height: 12),
        EverglowSkeleton(width: double.infinity, height: 170, radius: 24),
      ],
    );
  }
}
