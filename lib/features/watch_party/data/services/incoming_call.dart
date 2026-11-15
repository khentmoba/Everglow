class IncomingCall {
  final String roomId;
  final String callerUid;
  final String callerName;
  final String mediaTitle;
  final String mediaPosterPath;
  final String mediaType;
  final int? tmdbId;
  final int? malId;
  final bool isAnime;
  final int? season;
  final int? episode;
  final DateTime seenAt;

  const IncomingCall({
    required this.roomId,
    required this.callerUid,
    required this.callerName,
    required this.mediaTitle,
    required this.mediaPosterPath,
    required this.mediaType,
    this.tmdbId,
    this.malId,
    this.isAnime = false,
    required this.season,
    required this.episode,
    required this.seenAt,
  });
}