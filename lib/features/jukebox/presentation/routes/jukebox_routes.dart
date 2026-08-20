import 'package:go_router/go_router.dart';
import '../pages/spotify_callback_page.dart';

final jukeboxRoutes = [
  GoRoute(
    path: '/spotify/callback',
    builder: (context, state) {
      final code = state.uri.queryParameters['code'];
      final error = state.uri.queryParameters['error'];
      return SpotifyCallbackPage(code: code, error: error);
    },
  ),
];
