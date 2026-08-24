/// A movie (or other library item) returned by the Jellyfin API.
class JellyfinMediaItem {
  final String id;
  final String name;
  final String? year;
  final String? overview;
  final int? runTimeTicks;
  final String? imageTag;

  const JellyfinMediaItem({
    required this.id,
    required this.name,
    this.year,
    this.overview,
    this.runTimeTicks,
    this.imageTag,
  });

  int get runtimeMinutes {
    final ticks = runTimeTicks;
    if (ticks == null || ticks <= 0) return 0;
    return (ticks / 600000000).round();
  }

  factory JellyfinMediaItem.fromJson(Map<String, dynamic> json) {
    return JellyfinMediaItem(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      year: json['ProductionYear']?.toString(),
      overview: json['Overview'] as String?,
      runTimeTicks: json['RunTimeTicks'] is num
          ? (json['RunTimeTicks'] as num).toInt()
          : null,
      imageTag:
          (json['ImageTags'] as Map<String, dynamic>?)?['Primary'] as String?,
    );
  }
}
