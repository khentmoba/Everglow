class WatchPartyServer {
  final String id;

  final String name;

  final String shortName;

  final String host;

  final String type;

  final String streamUrl;

  final String? subtitleUrl;

  final bool proxyEnabled;

  final bool isRecommended;

  final bool isCustom;

  static const WatchPartyServer everglow = WatchPartyServer(
    id: 'everglow-builtin',
    name: 'Everglow',
    shortName: 'Everglow',
    host: 'everglow',
    type: 'everglow',
    streamUrl: '',
    isRecommended: true,
  );

  const WatchPartyServer({
    required this.id,
    required this.name,
    required this.shortName,
    required this.host,
    required this.type,
    required this.streamUrl,
    this.subtitleUrl,
    this.proxyEnabled = false,
    this.isRecommended = false,
    this.isCustom = false,
  });

  bool get isEverglow => type == 'everglow';
  bool get isHls => type == 'hls' || isEverglow;
  bool get isEmbed => type == 'embed';

  factory WatchPartyServer.fromJson(Map<String, dynamic> json) {
    return WatchPartyServer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortName:
          json['shortName'] as String? ?? (json['name'] as String? ?? ''),
      host: json['host'] as String? ?? '',
      type: json['type'] as String? ?? 'hls',
      streamUrl: json['streamUrl'] as String? ?? '',
      subtitleUrl: json['subtitleUrl'] as String?,
      proxyEnabled: json['proxyEnabled'] as bool? ?? false,
      isRecommended: json['isRecommended'] as bool? ?? false,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'host': host,
      'type': type,
      'streamUrl': streamUrl,
      if (subtitleUrl != null) 'subtitleUrl': subtitleUrl,
      'proxyEnabled': proxyEnabled,
      'isRecommended': isRecommended,
      'isCustom': isCustom,
    };
  }

  factory WatchPartyServer.fromRoom({
    required String serverType,
    required String serverName,
    required String serverHost,
    required String streamUrl,
    String? subtitleUrl,
    bool proxyEnabled = false,
  }) {
    return WatchPartyServer(
      id: serverHost.isNotEmpty ? serverHost : streamUrl,
      name: serverName.isNotEmpty ? serverName : serverHost,
      shortName: serverName.isNotEmpty ? serverName : serverHost,
      host: serverHost,
      type: serverType,
      streamUrl: streamUrl,
      subtitleUrl: subtitleUrl,
      proxyEnabled: proxyEnabled,
    );
  }

  WatchPartyServer copyWith({
    String? name,
    String? shortName,
    String? host,
    String? type,
    String? streamUrl,
    String? subtitleUrl,
    bool? proxyEnabled,
    bool? isRecommended,
    bool? isCustom,
  }) {
    return WatchPartyServer(
      id: id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      host: host ?? this.host,
      type: type ?? this.type,
      streamUrl: streamUrl ?? this.streamUrl,
      subtitleUrl: subtitleUrl ?? this.subtitleUrl,
      proxyEnabled: proxyEnabled ?? this.proxyEnabled,
      isRecommended: isRecommended ?? this.isRecommended,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}
