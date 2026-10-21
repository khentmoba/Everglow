enum EveningEnergy { quiet, playful, adventurous }

class TonightPreferences {
  final int? minutes;
  final bool goingOut;
  final EveningEnergy energy;

  const TonightPreferences({
    this.minutes,
    this.goingOut = false,
    this.energy = EveningEnergy.quiet,
  });

  Map<String, dynamic> toMap() => {
    'minutes': minutes,
    'goingOut': goingOut,
    'energy': energy.name,
  };

  factory TonightPreferences.fromMap(Map<String, dynamic>? data) {
    final minutes = data?['minutes'];
    return TonightPreferences(
      minutes: minutes is int && {30, 45, 90, 180}.contains(minutes)
          ? minutes
          : null,
      goingOut: data?['goingOut'] == true,
      energy: EveningEnergy.values.firstWhere(
        (e) => e.name == data?['energy'],
        orElse: () => EveningEnergy.quiet,
      ),
    );
  }
}
