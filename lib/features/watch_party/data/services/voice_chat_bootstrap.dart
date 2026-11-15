import '../../../../core/utils/logger.dart';
import 'incoming_call.dart';
import 'voice_chat_service.dart' deferred as voice_lib;

class VoiceChatBootstrap {
  VoiceChatBootstrap._();

  static bool _loaded = false;
  static Future<void>? _inflight;

  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _inflight ??= voice_lib
        .loadLibrary()
        .then((_) {
          _loaded = true;
        })
        .catchError((Object e, StackTrace st) {
          _inflight = null;
          Logger.e(
            'VoiceChatBootstrap: failed to load voice library chunk',
            error: e,
            stackTrace: st,
          );
          throw e;
        });
  }

  static Future<void> watchIncoming({
    required String myUid,
    required String? partnerUid,
  }) async {
    try {
      await ensureLoaded();
      voice_lib.VoiceChatService.watchIncoming(
        myUid: myUid,
        partnerUid: partnerUid,
      );
    } catch (e) {
      Logger.w(
        'VoiceChatBootstrap: cannot watch incoming calls (chunk load failed: $e)',
      );
    }
  }

  static void clearIncomingWatcher() {
    if (!_loaded) return;
    voice_lib.VoiceChatService.clearIncomingWatcher();
  }

  static IncomingCall? get latestIncoming =>
      _loaded ? voice_lib.VoiceChatService.latestIncoming : null;

  static Stream<IncomingCall?> get incomingStream => _loaded
      ? voice_lib.VoiceChatService.incomingStream
      : const Stream.empty();
}
