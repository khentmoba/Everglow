import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Fallback screen for unmatched routes.
class AppErrorPage extends StatelessWidget {
  const AppErrorPage({super.key, required this.uri});

  final Uri uri;

  /// Where "Go home" should land. Logged-in users go back to their own
  /// home (dashboard for the couple, cinema for cinema-only profiles) so
  /// a dead link never drops them at the passcode door. Logged-out users
  /// go to the gate. Pure so it unit-tests without Firebase.

  static String homeRouteFor({
    required bool isAuthenticated,
    required bool isCinemaOnlyUser,
  }) {
    if (!isAuthenticated) return '/';
    return isCinemaOnlyUser ? '/cinema' : '/dashboard';
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
                  // Same "authed" definition as the router redirect:
                  // a real Firebase session or a persisted offline name.
                  final authed = auth.isAuthenticated ||
                      auth.currentUser != null;
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
