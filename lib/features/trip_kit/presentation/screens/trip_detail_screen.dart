import 'dart:async';

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
  final TripKitService? service;
  const TripDetailScreen({super.key, required this.tripId, this.service});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

const double _kMaxContentWidth = 720;

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _packController = TextEditingController();
  bool _addingPackItem = false;
  bool _addingPlace = false;
  final _expenseLabel = TextEditingController();
  final _expenseAmount = TextEditingController();
  final _placeName = TextEditingController();
  final _placeNote = TextEditingController();

  TripKitService get _service => widget.service ?? TripKitService();

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
    final service = _service;

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
                    icon: Icons.auto_awesome_rounded,
                    label: 'Ask Motchi about this trip',
                    onTap: () => context.push(
                      '/motchi',
                      extra:
                          'Help me with our trip "${trip.title}" to ${trip.destination}. The trip id is ${trip.id}. What should we plan next?',
                    ),
                  ),
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
                        TripBudgetCard(trip: trip, service: service),
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

  Future<void> _addPackItem(Trip trip) async {
    if (_addingPackItem) return;
    final label = _packController.text.trim();
    if (label.isEmpty) return;
    await _savePackItem(
      trip,
      TripPackItem(id: Trip.newId(), label: label),
      label,
    );
  }

  Future<void> _savePackItem(Trip trip, TripPackItem item, String label) async {
    if (_addingPackItem) return;
    _addingPackItem = true;
    try {
      await _runTripAction(
        'Could not add this item. Your text is still here.',
        () async {
          await _service.addPackingItem(trip.id, item);
          if (mounted && _packController.text.trim() == label) {
            _packController.clear();
          }
        },
        onRetry: () => unawaited(_savePackItem(trip, item, label)),
      );
    } finally {
      _addingPackItem = false;
    }
  }

  Future<void> _togglePackItem(Trip trip, TripPackItem item) => _runTripAction(
    'Could not update this packing item. Please try again.',
    () => _service.setPackingItemPacked(
      trip.id,
      item.id,
      !item.packed,
      packedBy: context.read<AuthService>().currentUser,
    ),
  );

  Future<void> _removePackItem(Trip trip, TripPackItem item) => _runTripAction(
    'Could not remove this packing item. Please try again.',
    () => _service.removePackingItem(trip.id, item.id),
  );

  // ── Places ────────────────────────────────────────────────

  Future<void> _addPlace(Trip trip) async {
    if (_addingPlace) return;
    final name = _placeName.text.trim();
    if (name.isEmpty) return;
    final note = _placeNote.text.trim();
    await _savePlace(
      trip,
      TripPlace(id: Trip.newId(), name: name, note: note),
      name,
      note,
    );
  }

  Future<void> _savePlace(
    Trip trip,
    TripPlace place,
    String name,
    String note,
  ) async {
    if (_addingPlace) return;
    _addingPlace = true;
    try {
      await _runTripAction(
        'Could not add this place. Your text is still here.',
        () async {
          await _service.addPlace(trip.id, place);
          if (mounted &&
              _placeName.text.trim() == name &&
              _placeNote.text.trim() == note) {
            _placeName.clear();
            _placeNote.clear();
          }
        },
        onRetry: () => unawaited(_savePlace(trip, place, name, note)),
      );
    } finally {
      _addingPlace = false;
    }
  }

  Future<void> _togglePlace(Trip trip, TripPlace place) => _runTripAction(
    'Could not update this place. Please try again.',
    () => _service.setPlaceDone(trip.id, place.id, !place.done),
  );

  Future<void> _removePlace(Trip trip, TripPlace place) => _runTripAction(
    'Could not remove this place. Please try again.',
    () => _service.removePlace(trip.id, place.id),
  );

  Future<void> _runTripAction(
    String message,
    Future<void> Function() action, {
    VoidCallback? onRetry,
  }) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Retry',
            onPressed:
                onRetry ?? () => unawaited(_runTripAction(message, action)),
          ),
        ),
      );
    }
  }

  // ── Notes + delete ───────────────────────────────────────

  Widget _notesCard(Trip trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.05),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
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
              style: AppTypography.outfitBold.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _deleteTrip(context, trip);
  }

  Future<void> _deleteTrip(BuildContext context, Trip trip) async {
    try {
      await _service.delete(trip.id);
      if (context.mounted) context.go('/trips');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete this trip. Please try again.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaited(_deleteTrip(context, trip)),
          ),
        ),
      );
    }
  }
}

// ── Budget card ─────────────────────────────────────────────

class TripBudgetCard extends StatefulWidget {
  final Trip trip;
  final TripKitService? service;
  const TripBudgetCard({super.key, required this.trip, this.service});

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
              color: (trip.overBudget ? AppColors.error : AppColors.auroraTeal)
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
                      trip.overBudget ? AppColors.error : AppColors.petalWhite,
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
                      trip.overBudget ? AppColors.error : AppColors.auroraTeal,
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
              _TripExpenseAdder(trip: trip, service: widget.service),
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
                            color: AppColors.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 16,
                          color: AppColors.petalWhite.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded)
                  for (final expense in trip.expenses)
                    _TripExpenseRow(
                      trip: trip,
                      expense: expense,
                      service: widget.service,
                    ),
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
          style: AppTypography.outfitBold.copyWith(fontSize: 20, color: color),
        ),
      ],
    );
  }
}

class _TripExpenseAdder extends StatefulWidget {
  final Trip trip;
  final TripKitService? service;
  const _TripExpenseAdder({required this.trip, this.service});

  @override
  State<_TripExpenseAdder> createState() => _TripExpenseAdderState();
}

class _TripExpenseAdderState extends State<_TripExpenseAdder> {
  final _label = TextEditingController();
  bool _saving = false;
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

  Future<void> _add() async {
    if (_saving) return;
    final label = _label.text.trim();
    final amountText = _amount.text.trim();
    final amount = double.tryParse(amountText) ?? 0;
    if (label.isEmpty || amount <= 0) return;
    final expense = TripExpense(id: Trip.newId(), label: label, amount: amount);
    await _saveExpense(widget.trip.id, expense, label, amountText);
  }

  Future<void> _saveExpense(
    String tripId,
    TripExpense expense,
    String label,
    String amountText,
  ) async {
    if (_saving) return;
    _saving = true;
    try {
      await (widget.service ?? TripKitService()).addExpense(tripId, expense);
      if (mounted &&
          _label.text.trim() == label &&
          _amount.text.trim() == amountText) {
        _label.clear();
        _amount.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not add this expense. Your text is still here.',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () =>
                unawaited(_saveExpense(tripId, expense, label, amountText)),
          ),
        ),
      );
    } finally {
      _saving = false;
    }
  }
}

class _TripExpenseRow extends StatelessWidget {
  final Trip trip;
  final TripExpense expense;
  final TripKitService? service;
  const _TripExpenseRow({
    required this.trip,
    required this.expense,
    this.service,
  });

  Future<void> _remove(BuildContext context) async {
    try {
      await (service ?? TripKitService()).removeExpense(trip.id, expense.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not remove this expense. Please try again.',
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaited(_remove(context)),
          ),
        ),
      );
    }
  }

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
              onTap: () => _remove(context),
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
