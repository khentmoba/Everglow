import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppErrorPage extends StatelessWidget {
  const AppErrorPage({super.key, required this.uri});

  final Uri uri;

  static String homeRouteFor({
    required bool isAuthenticated,
    required bool isCinemaOnlyUser,
  }) {
    if (!isAuthenticated) return '/';
    return isCinemaOnlyUser ? '/cinema' : '/dashboard';
  }

  static String? cinemaOnlyRedirect(String loc) {
    final path = Uri.parse(loc).path;
    if (path == '/') return null;
    for (final section in const ['/cinema', '/anime', '/manga', '/books']) {
      if (path == section || path.startsWith('$section/')) return null;
    }
    return '/cinema';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.petalWhite,
            ),
            const SizedBox(height: 24),
            Text(
              'Page not found',
              style: AppTypography.cormorantBlack.copyWith(
                fontSize: 28,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              uri.toString(),
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 14,
                color: AppColors.petalWhite.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                var home = '/';
                try {
                  final auth = context.read<AuthService>();
                  final authed =
                      auth.isAuthenticated || auth.currentUser != null;
                  home = homeRouteFor(
                    isAuthenticated: authed,
                    isCinemaOnlyUser: auth.isCinemaOnlyUser,
                  );
                } catch (_) {
                  // No auth provider above us (tests, odd shells):
                  // fall back to the gate, which is always safe.
                }
                GoRouter.of(context).go(home);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepRose,
                foregroundColor: AppColors.petalWhite,
              ),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}
