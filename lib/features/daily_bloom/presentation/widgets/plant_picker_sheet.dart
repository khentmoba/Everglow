import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../data/models/plant_type.dart';

/// Bottom sheet for selecting a garden plant type.
class PlantPickerSheet extends StatelessWidget {
  final String currentPlantType;
  final ValueChanged<String> onSelected;

  const PlantPickerSheet({
    super.key,
    required this.currentPlantType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: AppTheme.velvet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppTheme.blushGold.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.petalWhite.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Choose Your Plant',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Each plant has a seasonal bonus month',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.petalWhite.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          ...PlantType.all.map((plant) => _buildPlantOption(context, plant)),
        ],
      ),
    );
  }

  Widget _buildPlantOption(BuildContext context, PlantType plant) {
    final isSelected = plant.id == currentPlantType;
    final inSeason = plant.isInSeason;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onSelected(plant.id);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.deepRose.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.blushGold
                    : AppTheme.blushGold.withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(plant.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plant.displayName,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppTheme.blushGold
                                  : AppTheme.petalWhite,
                            ),
                          ),
                          if (inSeason) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.blushGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${plant.seasonalBonusName} ✨',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.blushGold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (plant.seasonalBonusName != null)
                        Text(
                          'Bonus: ${plant.seasonalBonusName}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppTheme.petalWhite.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.blushGold,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show the plant picker as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String currentPlantType,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PlantPickerSheet(
        currentPlantType: currentPlantType,
        onSelected: onSelected,
      ),
    );
  }
}
