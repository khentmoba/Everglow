import 'lastfm_image_utils.dart';

class MusicStatus {
  final String username;
  final String trackName;
  final String artistName;
  final String albumName;
  final String? imageUrl;
  final bool isPlaying;
  final String spotifyUrl;
  final DateTime? timestamp;
  final String? spotifyTrackId;
  final String? spotifyEmbedUrl;
  final String? previewUrl;

  MusicStatus({
    required this.username,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    this.imageUrl,
    required this.isPlaying,
    required this.spotifyUrl,
    this.timestamp,
    this.spotifyTrackId,
    this.spotifyEmbedUrl,
    this.previewUrl,
  });

  /// True when we have a resolved Spotify track (not just a search URL).
  bool get hasSpotifyTrack => spotifyTrackId != null && spotifyTrackId!.isNotEmpty;

  String get resolvedSpotifyUrl => hasSpotifyTrack
      ? 'https://open.spotify.com/track/$spotifyTrackId'
      : spotifyUrl;

  String? get embedUrl => spotifyEmbedUrl ??
      (hasSpotifyTrack ? 'https://open.spotify.com/embed/track/$spotifyTrackId' : null);

  factory MusicStatus.fromJson(Map<String, dynamic> json, String username) {
    final track = json['recenttracks']['track'][0];
    return MusicStatus.fromTrackJson(track, username);
  }

  /// Parses a single Last.fm recent-track entry into a [MusicStatus].
  ///
  /// Shared by `user.getrecenttracks` responses of any limit (1 for the
  /// "vibing" card, 5 for the dashboard's recent-listen list).
  factory MusicStatus.fromTrackJson(
    Map<String, dynamic> track,
    String username,
  ) {
    final name = track['name'] as String;
    final artist = track['artist']['#text'] as String;
    final album = track['album']['#text'] as String;

    final images = track['image'] as List<dynamic>?;
    String? imgUrl;
    if (images != null && images.isNotEmpty) {
      dynamic selectedImage = images.last;
      for (var img in images) {
        if (img['size'] == 'extralarge') {
          selectedImage = img;
          break;
        }
      }
      imgUrl = cleanLastfmImageUrl(selectedImage['#text'] as String?);
    }

    final attr = track['@attr'];
    final nowPlaying = attr != null && attr['nowplaying'] == 'true';

    final spotifySearchUrl = 'https://open.spotify.com/search/${Uri.encodeComponent("$artist $name")}';

    DateTime? date;
    if (track['date'] != null) {
      final uts = int.tryParse(track['date']['uts'].toString());
      if (uts != null) {
        date = DateTime.fromMillisecondsSinceEpoch(uts * 1000);
      }
    }

    return MusicStatus(
      username: username,
      trackName: name,
      artistName: artist,
      albumName: album,
      imageUrl: imgUrl,
      isPlaying: nowPlaying,
      spotifyUrl: spotifySearchUrl,
      timestamp: date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'trackName': trackName,
      'artistName': artistName,
      'albumName': albumName,
      'imageUrl': imageUrl,
      'isPlaying': isPlaying,
      'spotifyUrl': spotifyUrl,
      'timestamp': timestamp?.toIso8601String(),
      if (spotifyTrackId != null) 'spotifyTrackId': spotifyTrackId,
      if (spotifyEmbedUrl != null) 'spotifyEmbedUrl': spotifyEmbedUrl,
      if (previewUrl != null) 'previewUrl': previewUrl,
    };
  }

  factory MusicStatus.fromMap(Map<String, dynamic> map) {
    return MusicStatus(
      username: map['username'] ?? '',
      trackName: map['trackName'] ?? 'Silent Night',
      artistName: map['artistName'] ?? 'Unknown Artist',
      albumName: map['albumName'] ?? 'No Album',
      imageUrl: map['imageUrl'],
      isPlaying: map['isPlaying'] ?? false,
      spotifyUrl: map['spotifyUrl'] ?? '',
      timestamp: map['timestamp'] != null ? DateTime.tryParse(map['timestamp']) : null,
      spotifyTrackId: map['spotifyTrackId'] as String?,
      spotifyEmbedUrl: map['spotifyEmbedUrl'] as String?,
      previewUrl: map['previewUrl'] as String?,
    );
  }

  factory MusicStatus.empty(String username) {
    return MusicStatus(
      username: username,
      trackName: 'Silent Night',
      artistName: 'Unknown Artist',
      albumName: 'No Album',
      isPlaying: false,
      spotifyUrl: 'https://open.spotify.com/search/Unknown%20Artist',
    );
  }

  MusicStatus copyWith({
    String? spotifyTrackId,
    String? spotifyEmbedUrl,
    String? previewUrl,
    String? spotifyUrl,
    String? imageUrl,
  }) {
    return MusicStatus(
      username: username,
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      imageUrl: imageUrl ?? this.imageUrl,
      isPlaying: isPlaying,
      spotifyUrl: spotifyUrl ?? this.spotifyUrl,
      timestamp: timestamp,
      spotifyTrackId: spotifyTrackId ?? this.spotifyTrackId,
      spotifyEmbedUrl: spotifyEmbedUrl ?? this.spotifyEmbedUrl,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}
