import 'package:cloud_firestore/cloud_firestore.dart';

/// One watch party room shared between Khent and Clair. A single document
/// in `watch_party_rooms/{roomId}` mirrors every state change: who's
/// hosting, what they're watching, and where in the playback each user
/// is right now. The other client subscribes via
/// [WatchPartyService.getRoomStream] and reacts in real time.
class WatchPartyRoom {
  /// The Firestore document id. Both users compute the same id by sorting
  /// their uids lexicographically and joining with `_`, so they always
  /// land on the same document without needing to negotiate one.
  final String id;

  /// Firebase Auth uid of whoever started the party. Useful for "host"
  /// UI affordances (the host gets the Play button, the partner gets
  /// a "Join" affordance).
  final String hostUid;

  /// Username of the host (`khentsgdz` or `clairjassen`). Used purely for
  /// display in the partner avatar and labels.
  final String hostName;

  /// The partner's uid. Persisted so the joiner doesn't need to know
  /// their own uid in the document — we just read `hostUid` and derive
  /// the partner.
  final String partnerUid;

  /// Username of the partner. Display only.
  final String partnerName;

  // ─── Media identity ────────────────────────────────────────────────
  // The three ids we need to replay the right embed: a TMDB id (for
  // movies / non-anime TV), a MAL id (for anime routed through Jikan),
  // and an `isAnime` flag so the player knows which URL builder to call.

  /// 'movie' or 'tv'. Series episode playback uses 'tv' + the
  /// `season` / `episode` fields below.
  final String mediaType;

  /// TMDB id. For anime this is empty (we route through the MAL id)
  /// unless the host opened an anime-sourced item, in which case the
  /// player will resolve TMDB via ani.zip.
  final int tmdbId;

  /// MAL id for anime items; null for non-anime.
  final int? malId;

  /// Anime flag — drives the URL builder and the embed provider pick.
  final bool isAnime;

  /// TV-only. Null for movies.
  final int? season;
  final int? episode;

  /// Display data (poster, title) so the partner's join screen can
  /// show a "Khent invited you to watch: <title>" card before they
  /// press Join.
  final String title;
  final String posterPath;

  // ─── Playback state ────────────────────────────────────────────────
  // This is the heart of the real-time sync. Every time the host (or
  // the partner) changes state, we rewrite this document with the new
  // values. The other client listens to the snapshot and reacts.

  /// 'playing' | 'paused' | 'buffering'. Drives the sync overlay
  /// ("Synced" vs "Paused by Khent" vs "Syncing to 0:23...").
  final String state;

  /// Estimated current playback position in seconds. Because the
  /// third-party iframe doesn't expose its timeline, both clients
  /// keep an internal clock and reconcile whenever one of them writes
  /// a new value here.
  final double currentTime;

  /// Server timestamp of the last state change. The other client
  /// uses `DateTime.now().difference(updatedAt)` to decide whether a
  /// received update is fresh or stale (e.g. host closed the tab 10
  /// minutes ago and the state is no longer trustworthy).
  final DateTime updatedAt;

  /// Uid of the user who made the last state change. Used so we don't
  /// react to our own writes (which would otherwise cause an infinite
  /// reload loop).
  final String updatedBy;

  // ─── Lifecycle ─────────────────────────────────────────────────────

  /// When the room was created. Used to age out stale rooms and to
  /// show "Started 5 min ago" in the join card.
  final DateTime createdAt;

  /// True while the party is live. Set to false when either user taps
  /// "End Party" or the host leaves; the partner's listener sees the
  /// flip and bounces them back to the cinema screen.
  final bool active;

  const WatchPartyRoom({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.partnerUid,
    required this.partnerName,
    required this.mediaType,
    required this.tmdbId,
    this.malId,
    required this.isAnime,
    this.season,
    this.episode,
    required this.title,
    required this.posterPath,
    required this.state,
    required this.currentTime,
    required this.updatedAt,
    required this.updatedBy,
    required this.createdAt,
    required this.active,
  });

  bool get isHost => updatedBy.isNotEmpty; // not used as a getter; see isUserHost helper
  bool get isPlaying => state == 'playing';
  bool get isPaused => state == 'paused';
  bool get isBuffering => state == 'buffering';

  /// Pretty "0:23" / "1:02:45" rendering for the sync overlay.
  String get formattedCurrentTime => _formatDuration(
        Duration(milliseconds: (currentTime * 1000).round()),
      );

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Build the deterministic room id from two uids. Sorting first
  /// means Khent and Clair always compute the same string regardless
  /// of which one of them opened the sheet first.
  static String buildRoomId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  factory WatchPartyRoom.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WatchPartyRoom(
      id: doc.id,
      hostUid: (data['hostUid'] as String?) ?? '',
      hostName: (data['hostName'] as String?) ?? '',
      partnerUid: (data['partnerUid'] as String?) ?? '',
      partnerName: (data['partnerName'] as String?) ?? '',
      mediaType: (data['mediaType'] as String?) ?? 'movie',
      tmdbId: (data['tmdbId'] as num?)?.toInt() ?? 0,
      malId: (data['malId'] is num) ? (data['malId'] as num).toInt() : null,
      isAnime: data['isAnime'] == true,
      season: (data['season'] is num) ? (data['season'] as num).toInt() : null,
      episode: (data['episode'] is num) ? (data['episode'] as num).toInt() : null,
      title: (data['title'] as String?) ?? '',
      posterPath: (data['posterPath'] as String?) ?? '',
      state: (data['state'] as String?) ?? 'paused',
      currentTime: (data['currentTime'] as num?)?.toDouble() ?? 0.0,
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      updatedBy: (data['updatedBy'] as String?) ?? '',
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      active: data['active'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostUid': hostUid,
      'hostName': hostName,
      'partnerUid': partnerUid,
      'partnerName': partnerName,
      'mediaType': mediaType,
      'tmdbId': tmdbId,
      if (malId != null) 'malId': malId,
      'isAnime': isAnime,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      'title': title,
      'posterPath': posterPath,
      'state': state,
      'currentTime': currentTime,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'active': active,
    };
  }

  WatchPartyRoom copyWith({
    String? state,
    double? currentTime,
    DateTime? updatedAt,
    String? updatedBy,
    bool? active,
  }) {
    return WatchPartyRoom(
      id: id,
      hostUid: hostUid,
      hostName: hostName,
      partnerUid: partnerUid,
      partnerName: partnerName,
      mediaType: mediaType,
      tmdbId: tmdbId,
      malId: malId,
      isAnime: isAnime,
      season: season,
      episode: episode,
      title: title,
      posterPath: posterPath,
      state: state ?? this.state,
      currentTime: currentTime ?? this.currentTime,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt,
      active: active ?? this.active,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// Tags an incoming room snapshot with a stable id so widgets can
/// detect "new snapshot" vs "same snapshot" and avoid rebuilding the
/// iframe on every tick when nothing has actually changed.
class WatchPartyUpdate {
  final WatchPartyRoom room;
  final DateTime receivedAt;

  /// True if the last state change came from us. WatchPartyScreen
  /// uses this to ignore our own writes (otherwise our local play
  /// press would re-load our own iframe, killing playback).
  final bool isLocal;

  const WatchPartyUpdate({
    required this.room,
    required this.receivedAt,
    required this.isLocal,
  });
}
