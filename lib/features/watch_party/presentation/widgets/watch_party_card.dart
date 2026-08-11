import 'package:flutter/material.dart';import 'package:provider/provider.dart';

import 'package:everglow/services/auth_service.dart';
import 'start_watch_party_button.dart';
import 'package:everglow/core/theme/app_typography.dart';

const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cMuted = Color(0xFF8A7A92);

/// Dashboard tile for the Watch Together feature. Mirrors the
/// shelf-card visual language of the Cinema / Anime / Books rails
/// (24px horizontal padding, glass card, accent icon block) so the
/// new feature sits naturally next to the existing shelves.
///
/// Cinematic-only profiles (Breyan, Octagram) get nothing — the
/// tile is hidden for them.
class WatchPartyCard extends StatelessWidget {
  const WatchPartyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isCouple = context.watch<AuthService>().isCoupleUser;
    if (!isCouple) return const SizedBox.shrink();

    // A "starter" media reference — used when the user hasn't
    // opened a specific title and just wants to see the active
    // room (if any) or be reminded of the feature. The button
    // widget handles resume-vs-start logic itself.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WatchPartyHeader(),
          const SizedBox(height: 14),
          StartWatchPartyButton(
            variant: WatchPartyButtonVariant.card,
            media: MediaRef(
              tmdbId: 0,
              mediaType: 'movie',
              title: 'A new adventure together',
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchPartyHeader extends StatelessWidget {
  const _WatchPartyHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_cDeepRose, Color(0xFF8E1444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _cDeepRose.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Watch Together',
                      style: AppTypography.cormorantBold.copyWith(fontSize: 24, height: 1.0, letterSpacing: 0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _cGold.withValues(alpha: 0.25),
                          _cGold.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _cGold.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: _cGold, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          'NEW',
                          style: AppTypography.outfitWhite.copyWith(color: _cGold, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'MOVIE NIGHT IN REAL TIME',
                style: AppTypography.outfitHeading.copyWith(color: _cMuted, fontSize: 10, letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
