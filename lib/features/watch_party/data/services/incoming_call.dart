/// One persistent in-app notification. Emitted by
/// [VoiceChatService.watchIncoming] when the partner has started
/// a watch party on the other side and this device is the callee.
/// Cleared (replaced with `null`) when the user opens the watch
/// party screen, when the partner ends the call, or when the room
/// doc disappears.
///
/// Lives in its own library (no `flutter_webrtc` dependency) so the
/// app-wide incoming-call banner can reference the type without pulling
/// the voice-chat chunk into the initial bundle.
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