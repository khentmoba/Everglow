/// Configuration for a single video embed source.
///
/// Mirrors the fields of the hardcoded [VideoProvider] classes in
/// [video_player_screen] and [watch_party_screen] so they can be
/// replaced by an instance loaded from Firestore (or a hardcoded
/// fallback).
class VideoSourceConfig {
  /// Stable internal identifier, e.g. "vidfast", "vidlink".
  final String id;

  /// Display name shown in the source picker, e.g. "VidFast".
  final String name;

  /// Short label for constrained UI (header badge, chip).
  final String shortName;

  /// One-line quality / feature hint shown in the picker.
  /// Examples: "Fast, multiple CDN domains", "Clean, modern player".
  final String desc;

  /// Base URL for movie embeds. Includes trailing slash when the
  /// embed expects it.
  final String movieUrl;

  /// Base URL for TV / episode embeds. Includes trailing slash when
  /// the embed expects it.
  final String tvUrl;

  /// Whether this source should be offered as a default / recommended
  /// option. Firestore-controlled so the app owner can promote a new
  /// fast source without a client release.
  final bool isRecommended;

  const VideoSourceConfig({
    required this.id,
    required this.name,
    required this.shortName,
    this.desc = '',
    required this.movieUrl,
    required this.tvUrl,
    this.isRecommended = false,
  });

  /// Deserialize from a Firestore document.
  factory VideoSourceConfig.fromFirestore(
    Map<String, dynamic> data, {
    String? id,
  }) {
    return VideoSourceConfig(
      id: id ?? (data['id'] as String? ?? ''),
      name: data['name'] as String? ?? '',
      shortName: data['shortName'] as String? ?? (data['name'] as String? ?? ''),
      desc: data['desc'] as String? ?? '',
      movieUrl: data['movieUrl'] as String? ?? '',
      tvUrl: data['tvUrl'] as String? ?? '',
      isRecommended: data['isRecommended'] as bool? ?? false,
    );
  }

  /// Serialize to a map suitable for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'desc': desc,
      'movieUrl': movieUrl,
      'tvUrl': tvUrl,
      'isRecommended': isRecommended,
    };
  }

  /// Deserialize from plain JSON (for the hardcoded fallback list).
  factory VideoSourceConfig.fromJson(Map<String, dynamic> json) {
    return VideoSourceConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortName: json['shortName'] as String? ?? (json['name'] as String? ?? ''),
      desc: json['desc'] as String? ?? '',
      movieUrl: json['movieUrl'] as String? ?? '',
      tvUrl: json['tvUrl'] as String? ?? '',
      isRecommended: json['isRecommended'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => toFirestore();
}
