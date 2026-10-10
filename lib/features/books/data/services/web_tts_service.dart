// Web builds use the browser's built-in Web Speech API.
// Non-web/VM test builds use the stub so they never touch `package:web`.
export 'web_tts_service_web.dart'
    if (dart.library.io) 'web_tts_service_stub.dart';
