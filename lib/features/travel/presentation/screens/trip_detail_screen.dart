import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../data/models/trip.dart';
import '../../data/services/travel_service.dart';
import '../widgets/add_pin_dialog.dart';

class TripDetailScreen extends StatelessWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final service = TravelService();
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraTeal,
                  alignment: Alignment(-0.6, -0.8),
                  size: 0.8,
                  opacity: 0.12,
                ),
              ],
              showPetals: false,
            ),
          ),
          SafeArea(
            child: StreamBuilder<List<Trip>>(
              stream: service.watchTrips(),
              builder: (context, snap) {
                final trips = snap.data ?? [];
                final trip = trips.where((t) => t.id == tripId).isEmpty
                    ? null
                    : trips.firstWhere((t) => t.id == tripId);
                if (trip == null) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.deepRose,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  return Center(
                    child: Text(
                      'Trip not found',
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppColors.petalWhite,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    EverglowFeatureHeader(
                      title: trip.title,
                      subtitle:
                          '${trip.startDate.month}/${trip.startDate.day} → ${trip.endDate.month}/${trip.endDate.day} • ${trip.days} days',
                      icon: Icons.map_rounded,
                      hue: AppColors.auroraTeal,
                      onBack: () => Navigator.pop(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.moonlight.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.auroraTeal.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.description.isEmpty
                                  ? 'No description'
                                  : trip.description,
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 12,
                                color: AppColors.petalWhite.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warmAmber.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${trip.budgetEstimate.toStringAsFixed(0)} ${trip.currency} est.',
                                    style: AppTypography.outfitWhite.copyWith(
                                      fontSize: 10,
                                      color: AppColors.warmAmber,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  trip.status.name,
                                  style: AppTypography.outfitBold.copyWith(
                                    fontSize: 11,
                                    color: AppColors.auroraTeal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _showAddPin(context, trip.id),
                                    icon: const Icon(
                                      Icons.add_location_alt_rounded,
                                      size: 14,
                                      color: AppColors.auroraTeal,
                                    ),
                                    label: Text(
                                      'Add pin',
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 11,
                                        color: AppColors.auroraTeal,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: AppColors.auroraTeal.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await service.autoJournalForTrip(trip);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Auto-journal hook queued',
                                            ),
                                            backgroundColor: AppColors.deepRose,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.auto_stories_rounded,
                                      size: 14,
                                    ),
                                    label: Text(
                                      'Auto-journal',
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 11,
                                        color: AppColors.petalWhite,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.deepRose,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<List<TripPin>>(
                        stream: service.watchPins(tripId),
                        builder: (context, snap) {
                          final pins = snap.data ?? [];
                          if (pins.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.place_outlined,
                                      size: 36,
                                      color: AppColors.blushGold.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No pins yet',
                                      style: AppTypography.outfitBold.copyWith(
                                        fontSize: 13,
                                        color: AppColors.petalWhite,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Pins are itinerary stops — Dawarich location + Surmai timeline',
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 11,
                                        color: AppColors.petalWhite.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          // Simple map preview at top
                          double minLat = pins
                              .map((p) => p.lat)
                              .reduce((a, b) => a < b ? a : b);
                          double maxLat = pins
                              .map((p) => p.lat)
                              .reduce((a, b) => a > b ? a : b);
                          double minLng = pins
                              .map((p) => p.lng)
                              .reduce((a, b) => a < b ? a : b);
                          double maxLng = pins
                              .map((p) => p.lng)
                              .reduce((a, b) => a > b ? a : b);
                          final latRange = (maxLat - minLat).abs() < 0.001
                              ? 1.0
                              : (maxLat - minLat);
                          final lngRange = (maxLng - minLng).abs() < 0.001
                              ? 1.0
                              : (maxLng - minLng);
                          return Column(
                            children: [
                              Container(
                                height: 160,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.twilight,
                                      AppColors.inkDeep,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.moonlight.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _GridPainter(),
                                        ),
                                      ),
                                      ...pins.asMap().entries.map((e) {
                                        final p = e.value;
                                        final nx = (p.lng - minLng) / lngRange;
                                        final ny =
                                            1 - (p.lat - minLat) / latRange;
                                        final x = 0.08 + nx * 0.84;
                                        final y = 0.10 + ny * 0.80;
                                        return Align(
                                          alignment: Alignment(
                                            x * 2 - 1,
                                            y * 2 - 1,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: p.isVisited
                                                  ? AppColors.success
                                                  : AppColors.deepRose,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${e.key + 1} ${p.emoji}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.petalWhite,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ReorderableListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  itemCount: pins.length,
                                  onReorderItem: (oldIdx, newIdx) async {
                                    final reordered = List<TripPin>.from(pins);
                                    final item = reordered.removeAt(oldIdx);
                                    reordered.insert(newIdx, item);
                                    for (int i = 0; i < reordered.length; i++) {
                                      await service.updatePin(
                                        reordered[i].copyWith(order: i),
                                      );
                                    }
                                  },
                                  itemBuilder: (context, idx) {
                                    final pin = pins[idx];
                                    return Container(
                                      key: ValueKey(pin.id),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.moonlight.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: pin.isVisited
                                              ? AppColors.success.withValues(
                                                  alpha: 0.3,
                                                )
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          ReorderableDragStartListener(
                                            index: idx,
                                            child: Icon(
                                              Icons.drag_handle_rounded,
                                              size: 16,
                                              color: AppColors.petalWhite
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: AppColors.auroraTeal
                                                  .withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${idx + 1}',
                                                style: AppTypography.outfitBold
                                                    .copyWith(
                                                      fontSize: 11,
                                                      color:
                                                          AppColors.auroraTeal,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      pin.emoji,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        pin.title,
                                                        style: AppTypography
                                                            .outfitBold
                                                            .copyWith(
                                                              fontSize: 12,
                                                              color: AppTheme
                                                                  .petalWhite,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    if (pin.isVisited)
                                                      const Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        size: 14,
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                  ],
                                                ),
                                                if (pin.note.isNotEmpty)
                                                  Text(
                                                    pin.note,
                                                    style: AppTypography
                                                        .outfitWhite
                                                        .copyWith(
                                                          fontSize: 10,
                                                          color: AppTheme
                                                              .petalWhite
                                                              .withValues(
                                                                alpha: 0.6,
                                                              ),
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                Text(
                                                  '${pin.lat.toStringAsFixed(4)}, ${pin.lng.toStringAsFixed(4)} • ${pin.category.name}',
                                                  style: AppTypography
                                                      .outfitWhite
                                                      .copyWith(
                                                        fontSize: 9,
                                                        color: AppTheme
                                                            .petalWhite
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                service.toggleVisited(pin),
                                            icon: Icon(
                                              pin.isVisited
                                                  ? Icons.check_box_rounded
                                                  : Icons
                                                        .check_box_outline_blank_rounded,
                                              size: 18,
                                              color: pin.isVisited
                                                  ? AppColors.success
                                                  : AppColors.petalWhite
                                                        .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                _confirmDelete(context, pin),
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color: AppColors.petalWhite
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPin(BuildContext context, String tripId) {
    showDialog(
      context: context,
      builder: (_) => AddPinDialog(tripId: tripId),
    );
  }

  void _confirmDelete(BuildContext context, TripPin pin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.velvet,
        title: Text(
          'Delete pin?',
          style: AppTypography.outfitBold.copyWith(color: AppColors.petalWhite),
        ),
        content: Text(
          pin.title,
          style: AppTypography.outfitWhite.copyWith(
            color: AppColors.petalWhite.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) await TravelService().deletePin(pin.id);
  }
}

extension _PinCopy on TripPin {
  TripPin copyWith({int? order}) => TripPin(
    id: id,
    tripId: tripId,
    title: title,
    note: note,
    lat: lat,
    lng: lng,
    category: category,
    order: order ?? this.order,
    visitedAt: visitedAt,
    photoUrl: photoUrl,
    createdBy: createdBy,
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.moonlight.withValues(alpha: 0.06)
      ..strokeWidth = 0.6;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
