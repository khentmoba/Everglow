import "incoming_call.dart";
import "voice_chat_service.dart" deferred as voice_lib;

/// Lazy entry point to the voice-chat incoming-call watcher.
///
/// `voice_chat_service.dart` pulls in `flutter_webrtc`, which must NOT sit
/// in the initial bundle: it delays first paint for every visitor, including
/// the 99% who never join a call on a given session. This bootstrap keeps a
/// tiny eager footprint (one deferred import) and loads the real chunk the
/// first time it is needed — typically right after login when [watchIncoming]
/// is called, in parallel with first paint rather than blocking it.
///
/// Rules:
/// - Always go through here from eager (main-bundle) code. Never import
///   `voice_chat_service.dart` eagerly outside the deferred watch-party chunk.
/// - [clearIncomingWatcher] is a safe no-op until the chunk has loaded
///   (there is nothing to clear before the watcher could have started).
/// - The [IncomingCall] *type* lives in `incoming_call.dart` (dependency-free)
///   so widgets can name it in signatures without loading the chunk.
class VoiceChatBootstrap {
  VoiceChatBootstrap._();

  static bool _loaded = false;
  static Future<void>? _inflight;

  /// Ensures the voice-chat chunk is loaded. Concurrent callers share one load.
  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _inflight ??= voice_lib.loadLibrary().then((_) {
      _loaded = true;
    });
  }

  /// Starts (or reuses) the global incoming-call watcher. Safe to call
  /// repeatedly; the chunk loads once.
  static Future<void> watchIncoming({
    required String myUid,
    required String? partnerUid,
  }) async {
    await ensureLoaded();
    voice_lib.VoiceChatService.watchIncoming(
      myUid: myUid,
      partnerUid: partnerUid,
    );
  }

  /// Stops the watcher. No-op until the chunk has loaded.
  static void clearIncomingWatcher() {
    if (!_loaded) return;
    voice_lib.VoiceChatService.clearIncomingWatcher();
  }

  /// Last known incoming call, or null before the chunk loads / when clear.
  static IncomingCall? get latestIncoming =>
      _loaded ? voice_lib.VoiceChatService.latestIncoming : null;

  /// Incoming-call broadcast. Only subscribe after [ensureLoaded] resolves;
  /// before that it is an empty stream that never emits.
  static Stream<IncomingCall?> get incomingStream => _loaded
      ? voice_lib.VoiceChatService.incomingStream
      : const Stream.empty();
}