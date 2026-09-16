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

  /// Whether this provider works inside a sandboxed iframe.
  /// When true, the iframe gets a sandbox attribute to trap ads.
  final bool sandboxSafe;

  const VideoSourceConfig({
    required this.id,
    required this.name,
    required this.shortName,
    this.desc = '',
    required this.movieUrl,
    required this.tvUrl,
    this.isRecommended = false,
    this.sandboxSafe = false,
  });

  /// Deserialize from a Firestore document.
  factory VideoSourceConfig.fromFirestore(
    Map<String, dynamic> data, {
    String? id,
  }) {
    final name = _toStr(data['name']);
    return VideoSourceConfig(
      id: id ?? _toStr(data['id']),
      name: name,
      shortName: _toStr(data['shortName'], fallback: name),
      desc: _toStr(data['desc']),
      movieUrl: _toStr(data['movieUrl']),
      tvUrl: _toStr(data['tvUrl']),
      isRecommended: _toBool(data['isRecommended']),
      sandboxSafe: _toBool(data['sandboxSafe']),
    );
  }

  static String _toStr(dynamic value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static bool _toBool(dynamic value) => value is bool ? value : false;

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
      'sandboxSafe': sandboxSafe,
    };
  }

  /// Deserialize from plain JSON (for the hardcoded fallback list).
  factory VideoSourceConfig.fromJson(Map<String, dynamic> json) {
    final name = _toStr(json['name']);
    return VideoSourceConfig(
      id: _toStr(json['id']),
      name: name,
      shortName: _toStr(json['shortName'], fallback: name),
      desc: _toStr(json['desc']),
      movieUrl: _toStr(json['movieUrl']),
      tvUrl: _toStr(json['tvUrl']),
      isRecommended: _toBool(json['isRecommended']),
      sandboxSafe: _toBool(json['sandboxSafe']),
    );
  }

  Map<String, dynamic> toJson() => toFirestore();
}
