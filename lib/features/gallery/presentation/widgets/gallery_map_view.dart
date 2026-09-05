import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/memory_photo.dart';
import '../../data/services/gallery_service.dart';

/// Immich-inspired map — lightweight stylized map with normalized pins.
/// No external map tiles; OSM link opens externally.
class GalleryMapView extends StatelessWidget {
  final List<MemoryPhoto> photos;
  const GalleryMapView({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    final located = photos.where((p) => p.hasLocation).toList();
    if (located.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: AppColors.blushGold.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'No pinned memories yet',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 14,
                  color: AppColors.petalWhite,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add a location when uploading — pins will appear on your world map',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 12,
                  color: AppColors.petalWhite.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Compute bounds to normalize
    double minLat = located
        .map((p) => p.latitude!)
        .reduce((a, b) => a < b ? a : b);
    double maxLat = located
        .map((p) => p.latitude!)
        .reduce((a, b) => a > b ? a : b);
    double minLng = located
        .map((p) => p.longitude!)
        .reduce((a, b) => a < b ? a : b);
    double maxLng = located
        .map((p) => p.longitude!)
        .reduce((a, b) => a > b ? a : b);
    final latRange = (maxLat - minLat).abs() < 0.001 ? 1.0 : (maxLat - minLat);
    final lngRange = (maxLng - minLng).abs() < 0.001 ? 1.0 : (maxLng - minLng);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.inkDeep.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.place_rounded,
                size: 16,
                color: AppColors.warmAmber,
              ),
              const SizedBox(width: 8),
              Text(
                '${located.length} pinned ${located.length == 1 ? 'memory' : 'memories'}',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  color: AppColors.petalWhite,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: AppColors.blushGold,
                ),
                label: Text(
                  'How it works',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 11,
                    color: AppColors.blushGold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.twilight, AppColors.inkDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.12),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Subtle grid + glow
                  Positioned.fill(
                    child: CustomPaint(painter: _MapGridPainter()),
                  ),
                  // Pins
                  ...located.map((p) {
                    final nx = (p.longitude! - minLng) / lngRange;
                    final ny =
                        1 - (p.latitude! - minLat) / latRange; // invert lat
                    // Clamp 0.08-0.92 to keep inside
                    final x = 0.08 + nx * 0.84;
                    final y = 0.10 + ny * 0.80;
                    return Align(
                      alignment: Alignment(x * 2 - 1, y * 2 - 1),
                      child: _MapPin(photo: p),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // List below map
        SizedBox(
          height: 92,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: located.length,
            itemBuilder: (context, idx) {
              final p = located[idx];
              return GestureDetector(
                onTap: () => _openPhoto(context, p),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.twilight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: AppNetworkImage(
                            imageUrl: GalleryService.displayUrl(p.imageUrl),
                            width: 140,
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            errorWidget: Container(
                              color: AppColors.velvet,
                              child: Icon(
                                Icons.image_outlined,
                                color: AppColors.petalWhite.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          p.locationName ??
                              '${p.latitude!.toStringAsFixed(2)}, ${p.longitude!.toStringAsFixed(2)}',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 10,
                            color: AppColors.petalWhite.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _openPhoto(BuildContext context, MemoryPhoto p) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: AppColors.velvet,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: AppNetworkImage(
                  imageUrl: GalleryService.displayUrl(p.imageUrl),
                  fit: BoxFit.cover,
                  cacheWidth: 600,
                  errorWidget: Container(
                    height: 200,
                    color: AppColors.twilight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.locationName != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.place_rounded,
                            size: 14,
                            color: AppColors.warmAmber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.locationName!,
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 12,
                                color: AppColors.warmAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (p.locationName != null) const SizedBox(height: 6),
                    Text(
                      p.caption.isEmpty ? 'No caption' : p.caption,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 13,
                        color: AppColors.petalWhite,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${p.latitude!.toStringAsFixed(4)}, ${p.longitude!.toStringAsFixed(4)} • by ${p.uploadedBy}',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 10,
                        color: AppColors.petalWhite.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse(
                                'https://www.openstreetmap.org/?mlat=${p.latitude}&mlon=${p.longitude}#map=15/${p.latitude}/${p.longitude}',
                              );
                              if (await canLaunchUrl(url)) {
                                await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.map_rounded,
                              size: 14,
                              color: AppColors.auroraTeal,
                            ),
                            label: Text(
                              'Open in OSM',
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
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Close',
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatefulWidget {
  final MemoryPhoto photo;
  const _MapPin({required this.photo});

  @override
  State<_MapPin> createState() => _MapPinState();
}

class _MapPinState extends State<_MapPin> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showQuick(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.all(_hovered ? 3 : 2),
              decoration: BoxDecoration(
                color: AppColors.petalWhite,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
                border: Border.all(color: AppColors.deepRose, width: 1.2),
              ),
              child: ClipOval(
                child: AppNetworkImage(
                  imageUrl: GalleryService.displayUrl(widget.photo.imageUrl),
                  width: _hovered ? 38 : 32,
                  height: _hovered ? 38 : 32,
                  fit: BoxFit.cover,
                  cacheWidth: 100,
                  errorWidget: Container(
                    width: 32,
                    height: 32,
                    color: AppColors.blushGold,
                  ),
                ),
              ),
            ),
            Container(width: 2, height: 8, color: AppColors.deepRose),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.deepRose,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuick(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.photo.locationName ?? widget.photo.caption),
        backgroundColor: AppColors.velvet,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.moonlight.withValues(alpha: 0.06)
      ..strokeWidth = 0.6;
    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Glow blobs
    final glow = Paint()..color = AppColors.deepRose.withValues(alpha: 0.07);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 80, glow);
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.65),
      65,
      glow..color = AppColors.warmAmber.withValues(alpha: 0.05),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
