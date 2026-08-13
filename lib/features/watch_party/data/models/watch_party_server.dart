/// A playback server available to the watch party.
///
/// This mirrors the AniChan `/api/watch/servers` contract: each server
/// exposes a display label, a stable host identity, a normalized stream
/// URL, and a `type` that tells the player whether to use hls.js or an
/// embed iframe. Everglow uses the same shape so server lists can be
/// pushed from Firestore (`config/watch_party_servers`) without a
/// client release, exactly like AniChan's server API.
class WatchPartyServer {
  /// Stable id, e.g. "jellyfin-khent" or "plex-clair".
  final String id;

  /// Full display name shown in the server picker.
  final String name;

  /// Short label for compact UI (chips, header badges).
  final String shortName;

  /// Machine identity reported with playback, e.g. "jellyfin" or "plex".
  final String host;

  /// 'hls' (m3u8 played with hls.js) or 'embed' (iframe page).
  final String type;

  /// Normalized stream URL. Relative URLs are resolved by the caller
  /// against the server's configured origin.
  final String streamUrl;

  /// Optional subtitle track (VTT) for HLS servers.
  final String? subtitleUrl;

  /// Route the stream through `proxyWatchStream` for CORS/hotlink
  /// protection. Mirrors AniChan routing streams through
  /// `/api/watch/m3u8` and `/api/watch/vtt`.
  final bool proxyEnabled;

  /// Promoted option, shown first with a star badge.
  final bool isRecommended;

  /// True when the user added this server locally instead of it coming
  /// from the shared Firestore config.
  final bool isCustom;

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

  bool get isHls => type == 'hls';
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

  /// Build a server entry from the fields persisted on a watch party
  /// room. Used when the partner joins after the host picked a server.
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
