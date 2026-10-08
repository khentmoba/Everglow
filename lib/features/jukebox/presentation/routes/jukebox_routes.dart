import 'package:go_router/go_router.dart';
import '../../../../core/router/deferred_route.dart';
import '../pages/spotify_callback_page.dart';
import '../screens/jukebox_screen.dart' deferred as jukebox_lib;

final jukeboxRoutes = [
  GoRoute(
    path: '/jukebox',
    builder: (_, _) => DeferredRouteLoader(
      label: 'Jukebox',
      loadLibrary: jukebox_lib.loadLibrary,
      builder: () => jukebox_lib.JukeboxScreen(),
    ),
  ),
  GoRoute(
    path: '/spotify/callback',
    builder: (context, state) {
      final code = state.uri.queryParameters['code'];
      final error = state.uri.queryParameters['error'];
      return SpotifyCallbackPage(code: code, error: error);
    },
  ),
];
