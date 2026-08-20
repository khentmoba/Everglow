// Conditional export: web uses real SDK, VM uses stub
export 'spotify_player_service_stub.dart' if (dart.library.js_interop) 'spotify_player_service_web.dart';
