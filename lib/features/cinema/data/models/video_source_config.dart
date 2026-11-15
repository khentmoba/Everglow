class VideoSourceConfig {
  final String id;

  final String name;

  final String shortName;

  final String desc;

  final String movieUrl;

  final String tvUrl;

  final bool isRecommended;

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
