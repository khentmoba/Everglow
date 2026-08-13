import 'package:go_router/go_router.dart';
import 'app_error_page.dart';

/// Reads a typed `extra` value without crashing on deep-link reloads.
///
/// Browser refreshes lose `GoRouterState.extra`, so route builders must
/// fall back to the error page instead of casting with `!`.
T? extraOf<T>(GoRouterState state) {
  final extra = state.extra;
  return extra is T ? extra : null;
}

/// Error page shown when a route requires an `extra` payload that is absent.
AppErrorPage missingExtraPage(GoRouterState state) {
  return AppErrorPage(uri: state.uri);
}
