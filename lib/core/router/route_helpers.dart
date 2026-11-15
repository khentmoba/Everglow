import 'package:go_router/go_router.dart';
import 'app_error_page.dart';

T? extraOf<T>(GoRouterState state) {
  final extra = state.extra;
  return extra is T ? extra : null;
}

AppErrorPage missingExtraPage(GoRouterState state) {
  return AppErrorPage(uri: state.uri);
}

String agentJumpLocation(Uri launch, String target) {
  if (launch.queryParameters['screencheck'] != '1') return target;
  final destination = Uri.parse(target);
  return destination
      .replace(
        queryParameters: {
          ...destination.queryParameters,
          ...launch.queryParameters,
        },
      )
      .toString();
}

String? deepLinkTarget(Uri gatewayUri, {required bool cinemaOnly}) {
  final from = gatewayUri.queryParameters['from'];
  if (from == null || from.isEmpty) return null;
  if (from.contains('..')) return null;
  final target = Uri.tryParse(from);
  if (target == null) return null;
  if (target.hasScheme || target.hasAuthority) return null;
  final path = target.path;
  if (!path.startsWith('/') || path.startsWith('//')) return null;
  if (path.contains('..')) return null;
  if (path == '/') return null;
  if (cinemaOnly && AppErrorPage.cinemaOnlyRedirect(path) != null) return null;
  return target.toString();
}
