import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'trip_list_screen.dart' show showTripEditSheet;

/// One trip page: packing checklist + budget + places, all live.
class TripDetailScreen extends StatefulWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

const double _kMaxContentWidth = 720;

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _packController = TextEditingController();
  final _expenseLabel = TextEditingController();
  final _expenseAmount = TextEditingController();
  final _placeName = TextEditingController();
  final _placeNote = TextEditingController();

  @override
  void dispose() {
    _packController.dispose();
    _expenseLabel.dispose();
    _expenseAmount.dispose();
    _placeName.dispose();
    _placeNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = TripKitService();

    return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      body: EverglowStreamView<Trip?>(
        stream: service.watchOne(widget.tripId),
        streamLabel: 'trip-kit-detail',
        errorMessage: 'Could not load trip',
        onRetry: () => setState(() {}),
        loadingView: const _LoadingTrip(),
        isEmpty: (trip) => trip == null,
        emptyView: EverglowEmptyState(
          icon: Icons.luggage_outlined,
          title: 'Trip not found',
          subtitle: 'It may have been deleted',
          ctaLabel: 'Back to trips',
          onCta: () => context.go('/trips'),
        ),
        builder: (context, trip) {
          trip!;
          return Column(
            children: [
              EverglowFeatureHeader(
                title: trip.title.isEmpty ? 'Untitled trip' : trip.title,
                subtitle: trip.destination.isEmpty
                    ? tripDateRange(trip)
                    : '${trip.destination} · ${tripDateRange(trip)}',
                icon: Icons.luggage_rounded,
                hue: AppColors.auroraTeal,
                actions: [
                  _HeaderIcon(
                    icon: Icons.edit_rounded,
                    label: 'Edit trip details',
                    onTap: () => showTripEditSheet(context, trip),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIcon(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete trip',
                    onTap: () => _confirmDelete(context, trip),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kMaxContentWidth,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                      children: [
                        if (trip.notes.isNotEmpty) _notesCard(trip),
                        TripBudgetCard(trip: trip),
                        TripSectionTitle(
                          icon: Icons.backpack_rounded,
                          title: 'PACKING',
                          hue: AppColors.warmAmber,
                          trailing: trip.packing.isEmpty
                              ? null
                              : '${trip.packedCount}/${trip.packing.length}',
                        ),
                        TripAddRow(
                          controller: _packController,
                          hint: 'Add to pack (e.g. Sunscreen)',
                          hue: AppColors.warmAmber,
                          onAdd: () => _addPackItem(trip),
                        ),
                        const SizedBox(height: 10),
                        for (final item in trip.packing)
                          TripCheckRow(
                            key: ValueKey('pack-${item.id}'),
                            label: item.label,
                            subtitle: item.packedBy,
                            checked: item.packed,
                            hue: AppColors.warmAmber,
                            toggleLabel: 'Pack ${item.label}',
                            onToggle: () => _togglePackItem(trip, item),
                            onDelete: () => _removePackItem(trip, item),
                          ),
                        TripSectionTitle(
                          icon: Icons.place_rounded,
                          title: 'PLACES',
                          hue: AppColors.auroraRose,
                          trailing: trip.places.isEmpty
                              ? null
                              : '${trip.visitedCount}/${trip.places.length}',
                        ),
                        TripAddRow(
                          controller: _placeName,
                          hint: 'Place',
                          hue: AppColors.auroraRose,
                          secondController: _placeNote,
                          secondHint: 'Note (optional)',
                          onAdd: () => _addPlace(trip),
                        ),
                        const SizedBox(height: 10),
                        for (final place in trip.places)
                          TripCheckRow(
                            key: ValueKey('place-${place.id}'),
                            label: place.name,
                            subtitle: place.note,
                            checked: place.done,
                            hue: AppColors.auroraRose,
                            toggleLabel: 'Visit ${place.name}',
                            onToggle: () => _togglePlace(trip, place),
                            onDelete: () => _removePlace(trip, place),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Packing ───────────────────────────────────────────────

  void _addPackItem(Trip trip) {
    final label = _packController.text.trim();
    if (label.isEmpty) return;
    _packController.clear();
    TripKitService().updatePacking(trip.id, [
      ...trip.packing,
      TripPackItem(id: Trip.newId(), label: label),
    ]);
  }

  void _togglePackItem(Trip trip, TripPackItem item) {
    final me = context.read<AuthService>().currentUser;
    TripKitService().updatePacking(
      trip.id,
      trip.packing
          .map(
            (e) => e.id == item.id
                ? e.copyWith(packed: !e.packed, packedBy: me)
                : e,
          )
          .toList(),
    );
  }

  void _removePackItem(Trip trip, TripPackItem item) {
    TripKitService().updatePacking(
      trip.id,
      trip.packing.where((e) => e.id != item.id).toList(),
    );
  }

  // ── Places ────────────────────────────────────────────────

  void _addPlace(Trip trip) {
    final name = _placeName.text.trim();
    if (name.isEmpty) return;
    final note = _placeNote.text.trim();
    _placeName.clear();
    _placeNote.clear();
    TripKitService().updatePlaces(trip.id, [
      ...trip.places,
      TripPlace(id: Trip.newId(), name: name, note: note),
    ]);
  }

  void _togglePlace(Trip trip, TripPlace place) {
    TripKitService().updatePlaces(
      trip.id,
      trip.places
          .map((e) => e.id == place.id ? e.copyWith(done: !e.done) : e)
          .toList(),
    );
  }

  void _removePlace(Trip trip, TripPlace place) {
    TripKitService().updatePlaces(
      trip.id,
      trip.places.where((e) => e.id != place.id).toList(),
    );
  }

  // ── Notes + delete ────────────────────────────────────────

  Widget _notesCard(Trip trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.05),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 15,
            color: AppColors.blushGold.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trip.notes,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 13,
                height: 1.45,
                color: AppColors.petalWhite.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Trip trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.velvet,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusX2),
        title: Text(
          'Delete this trip?',
          style: AppTypography.cormorantBold.copyWith(
            fontSize: 22,
            color: AppColors.petalWhite,
          ),
        ),
        content: Text(
          'Packing, budget, and places go with it. This cannot be undone.',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 13,
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep it',
              style: AppTypography.outfitBold.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppTypography.outfitBold.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await TripKitService().delete(trip.id);
      if (context.mounted) context.go('/trips');
    }
  }
}

// ── Budget card ─────────────────────────────────────────────

class TripBudgetCard extends StatefulWidget {
  final Trip trip;
  const TripBudgetCard({super.key, required this.trip});

  @override
  State<TripBudgetCard> createState() => TripBudgetCardState();
}

class TripBudgetCardState extends State<TripBudgetCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Column(
      children: [
        TripSectionTitle(
          icon: Icons.wallet_rounded,
          title: 'BUDGET',
          hue: AppColors.auroraTeal,
          trailing: trip.budgetTotal > 0
              ? '${tripPeso(trip.spentTotal)} / ${tripPeso(trip.budgetTotal)}'
              : '${tripPeso(trip.spentTotal)} spent',
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.silk, AppColors.velvet],
            ),
            borderRadius: AppRadius.radiusX2,
            border: Border.all(
              color: (trip.overBudget
                      ? AppColors.error
                      : AppColors.auroraTeal)
                  .withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _budgetNumber(
                      'Spent',
                      tripPeso(trip.spentTotal),
                      trip.overBudget
                          ? AppColors.error
                          : AppColors.petalWhite,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.moonlight.withValues(alpha: 0.12),
                  ),
                  Expanded(
                    child: _budgetNumber(
                      trip.budgetTotal > 0 ? 'Left' : 'Budget',
                      trip.budgetTotal > 0
                          ? tripPeso(trip.remaining)
                          : 'Not set',
                      trip.budgetTotal > 0 && trip.remaining < 0
                          ? AppColors.error
                          : AppColors.auroraTeal,
                    ),
                  ),
                ],
              ),
              if (trip.budgetTotal > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: AppRadius.radiusFull,
                  child: LinearProgressIndicator(
                    value: trip.budgetProgress,
                    minHeight: 8,
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
                if (trip.overBudget)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Over budget by ${tripPeso(-trip.remaining)} — worth it? 💸',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              _TripExpenseAdder(trip: trip),
              if (trip.expenses.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(
                          '${trip.expenses.length} expense${trip.expenses.length == 1 ? '' : 's'}',
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 12,
                            color: AppColors.petalWhite.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 16,
                          color: AppColors.petalWhite.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded)
                  for (final expense in trip.expenses)
                    _TripExpenseRow(trip: trip, expense: expense),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _budgetNumber(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.outfitBold.copyWith(
            fontSize: 10,
            letterSpacing: 1.4,
            color: AppColors.petalWhite.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.outfitBold.copyWith(
            fontSize: 20,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TripExpenseAdder extends StatefulWidget {
  final Trip trip;
  const _TripExpenseAdder({required this.trip});

  @override
  State<_TripExpenseAdder> createState() => _TripExpenseAdderState();
}

class _TripExpenseAdderState extends State<_TripExpenseAdder> {
  final _label = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TripAddRow(
      controller: _label,
      hint: 'What (e.g. Gas)',
      hue: AppColors.auroraTeal,
      secondController: _amount,
      secondHint: '₱',
      secondKeyboardType: TextInputType.number,
      onAdd: _add,
    );
  }

  void _add() {
    final label = _label.text.trim();
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (label.isEmpty || amount <= 0) return;
    _label.clear();
    _amount.clear();
    final trip = widget.trip;
    TripKitService().updateExpenses(trip.id, [
      ...trip.expenses,
      TripExpense(id: Trip.newId(), label: label, amount: amount),
    ]);
  }
}

class _TripExpenseRow extends StatelessWidget {
  final Trip trip;
  final TripExpense expense;
  const _TripExpenseRow({required this.trip, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.moonlight.withValues(alpha: 0.05),
          borderRadius: AppRadius.radiusLg,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                expense.label,
                style: AppTypography.outfitWhite.copyWith(fontSize: 13),
              ),
            ),
            Text(
              tripPeso(expense.amount),
              style: AppTypography.outfitBold.copyWith(
                fontSize: 13,
                color: AppColors.auroraTeal,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => TripKitService().updateExpenses(
                trip.id,
                trip.expenses.where((e) => e.id != expense.id).toList(),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.petalWhite.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header icon + loading ─────────────────────────────────────

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeaderIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.moonlight.withValues(alpha: 0.08),
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.14),
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: AppColors.petalWhite.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

class _LoadingTrip extends StatelessWidget {
  const _LoadingTrip();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 90, 16, 24),
      children: const [
        EverglowSkeleton(width: double.infinity, height: 190, radius: 24),
        SizedBox(height: 12),
        EverglowSkeleton(width: double.infinity, height: 60, radius: 16),
        SizedBox(height: 10),
        EverglowSkeleton(width: double.infinity, height: 60, radius: 16),
      ],
    );
  }
}
