import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/trip.dart';
import '../../data/services/travel_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TravelAtlasView extends StatelessWidget {
  const TravelAtlasView({super.key});

  @override
  Widget build(BuildContext context) {
    final service = TravelService();
    return StreamBuilder<List<TripPin>>(
      stream: service.watchAllPins(),
      builder: (context, snap) {
        final pins = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.deepRose, strokeWidth: 2));
        if (pins.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public_rounded, size: 48, color: AppColors.auroraTeal.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text('Atlas is empty', style: AppTypography.outfitBold.copyWith(fontSize: 14, color: AppTheme.petalWhite)),
                  const SizedBox(height: 6),
                  Text('Add pins to trips — your Dawarich world map will bloom', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.6)), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        // Stylized map same as gallery map
        double minLat = pins.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
        double maxLat = pins.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
        double minLng = pins.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
        double maxLng = pins.map((p) => p.lng).reduce((a, b) => a > b ? a : b);
        final latRange = (maxLat - minLat).abs() < 0.001 ? 1.0 : (maxLat - minLat);
        final lngRange = (maxLng - minLng).abs() < 0.001 ? 1.0 : (maxLng - minLng);

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.15))),
              child: Row(children: [Icon(Icons.place_rounded, size: 14, color: AppColors.auroraTeal), const SizedBox(width: 8), Text('${pins.length} pins • ${pins.where((p) => p.isVisited).length} visited', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppTheme.petalWhite)), const Spacer(), Text('Dawarich', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.auroraTeal))]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.twilight, AppColors.inkDeep]), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.12))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _AtlasGridPainter())),
                      ...pins.map((p) {
                        final nx = (p.lng - minLng) / lngRange;
                        final ny = 1 - (p.lat - minLat) / latRange;
                        final x = 0.08 + nx * 0.84;
                        final y = 0.10 + ny * 0.80;
                        return Align(alignment: Alignment(x * 2 - 1, y * 2 - 1), child: _AtlasPin(pin: p));
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: pins.length,
                itemBuilder: (context, idx) {
                  final p = pins[idx];
                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.twilight, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.isVisited ? AppColors.success.withValues(alpha: 0.3) : AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Text(p.emoji, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6), Expanded(child: Text(p.title, style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppTheme.petalWhite), maxLines: 1, overflow: TextOverflow.ellipsis)), if (p.isVisited) Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success)]),
                        const SizedBox(height: 4),
                        Text(p.note.isEmpty ? '${p.lat.toStringAsFixed(2)}, ${p.lng.toStringAsFixed(2)}' : p.note, style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.6)), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _AtlasPin extends StatelessWidget {
  final TripPin pin;
  const _AtlasPin({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(color: pin.isVisited ? AppColors.success : AppColors.deepRose, borderRadius: BorderRadius.circular(6)),
          child: Text(pin.emoji, style: const TextStyle(fontSize: 12)),
        ),
        Container(width: 2, height: 6, color: AppColors.deepRose),
        Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.deepRose, shape: BoxShape.circle)),
      ],
    );
  }
}

class _AtlasGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.moonlight.withValues(alpha: 0.06)..strokeWidth = 0.6;
    for (double x = 0; x < size.width; x += 36) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += 36) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
