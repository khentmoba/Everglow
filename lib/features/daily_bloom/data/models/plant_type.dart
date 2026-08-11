/// Represents a plant type in the garden with its visual characteristics.
class PlantType {
  final String id;
  final String displayName;
  final String emoji;
  final List<String> stageDescriptions;
  final int? seasonalBonusMonth; // Month (1-12) when this plant gets +1 stage
  final String? seasonalBonusName; // e.g., "Spring Bloom"

  const PlantType({
    required this.id,
    required this.displayName,
    required this.emoji,
    required this.stageDescriptions,
    this.seasonalBonusMonth,
    this.seasonalBonusName,
  });

  static const List<PlantType> all = [
    PlantType(
      id: 'lily',
      displayName: 'Lily',
      emoji: '🌸',
      stageDescriptions: [
        'Empty pot',
        'A tiny sprout',
        'Growing bud',
        'Opening bloom',
        'Half bloom',
        'Full bloom',
      ],
    ),
    PlantType(
      id: 'rose',
      displayName: 'Rose',
      emoji: '🌹',
      stageDescriptions: [
        'Empty pot',
        'A tiny sprout',
        'Thorny stem',
        'Rose bud',
        'Opening rose',
        'Full rose',
      ],
      seasonalBonusMonth: 2, // February (Valentine's)
      seasonalBonusName: 'Valentine\'s Bloom',
    ),
    PlantType(
      id: 'sunflower',
      displayName: 'Sunflower',
      emoji: '🌻',
      stageDescriptions: [
        'Empty pot',
        'A tiny sprout',
        'Tall stem',
        'Budding head',
        'Opening petals',
        'Full sunflower',
      ],
      seasonalBonusMonth: 7, // July (summer)
      seasonalBonusName: 'Summer Radiance',
    ),
    PlantType(
      id: 'tulip',
      displayName: 'Tulip',
      emoji: '🌷',
      stageDescriptions: [
        'Empty pot',
        'A tiny sprout',
        'Slender stem',
        'Tulip bud',
        'Opening tulip',
        'Full tulip',
      ],
      seasonalBonusMonth: 4, // April (spring)
      seasonalBonusName: 'Spring Awakening',
    ),
    PlantType(
      id: 'sakura',
      displayName: 'Sakura',
      emoji: '🌸',
      stageDescriptions: [
        'Empty pot',
        'A tiny sprout',
        'Branching tree',
        'Cherry buds',
        'Opening blossoms',
        'Full sakura',
      ],
      seasonalBonusMonth: 3, // March
      seasonalBonusName: 'Hanami Season',
    ),
  ];

  static PlantType fromId(String id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => all.first, // Default to lily
    );
  }

  /// Returns the effective stage, applying seasonal bonus if applicable.
  int effectiveStage(int baseStage) {
    final now = DateTime.now();
    if (seasonalBonusMonth != null && now.month == seasonalBonusMonth) {
      return (baseStage + 1).clamp(0, 5);
    }
    return baseStage;
  }

  /// Whether this plant is currently in its bonus season.
  bool get isInSeason {
    if (seasonalBonusMonth == null) return false;
    return DateTime.now().month == seasonalBonusMonth;
  }
}
