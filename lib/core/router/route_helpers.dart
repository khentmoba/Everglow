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

/// Where to send the user after the gateway login.
///
/// The router bounces logged-out deep links to `/?from=<intended page>`
/// instead of plain `/`, so a PR preview link like `<preview>/cinema`
/// lands straight on the fixed screen after one login instead of the
/// dashboard. Returns null when there is no remembered target, so the
/// caller falls back to its default home.
///
/// Safety: the `from` value comes from the URL bar, so only internal
/// paths are accepted (no scheme, host, `..`, or protocol-relative `//`).
/// Cinema-only users are kept inside `/cinema`.
String? deepLinkTarget(Uri gatewayUri, {required bool cinemaOnly}) {
  final from = gatewayUri.queryParameters['from'];
  if (from == null || from.isEmpty) return null;
  // Check the raw value: Uri parsing already resolves `/a/../b` into
  // `/b`, so the parsed path can never be trusted for this test.
  if (from.contains('..')) return null;
  final target = Uri.tryParse(from);
  if (target == null) return null;
  if (target.hasScheme || target.hasAuthority) return null;
  final path = target.path;
  if (!path.startsWith('/') || path.startsWith('//')) return null;
  if (path.contains('..')) return null;
  if (path == '/') return null;
  if (cinemaOnly && !path.startsWith('/cinema')) return null;
  return target.toString();
}
