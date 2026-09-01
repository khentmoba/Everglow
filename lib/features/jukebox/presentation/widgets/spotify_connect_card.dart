import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/services/spotify_auth_service.dart';
import '../../data/services/spotify_player_service.dart';

/// Shows Duo link status + connect button. Drop into JukeboxWidget header or dashboard.
class SpotifyConnectCard extends StatelessWidget {
  const SpotifyConnectCard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<SpotifyAuthService>();
    final player = context.watch<SpotifyPlayerService>();
    final isLinked = auth.isLinked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.velvet.withValues(alpha: 0.6),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              size: 16,
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLinked ? 'Spotify linked' : 'Connect Spotify',
                  style: const TextStyle(
                    color: AppColors.petalWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isLinked
                      ? (auth.displayName ?? auth.spotifyUserId ?? 'Premium ✓')
                      : 'For in-app playback (Duo required)',
                  style: TextStyle(
                    color: AppColors.petalWhite.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                if (player.deviceId != null)
                  Text(
                    'Device: ${player.deviceId!.substring(0, 8)}…',
                    style: TextStyle(
                      color: AppColors.petalWhite.withValues(alpha: 0.45),
                      fontSize: 10,
                    ),
                  ),
                if (player.error != null)
                  Text(
                    player.error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!isLinked)
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await context.read<SpotifyAuthService>().linkSpotify();
                } catch (e) {
                  final msg = e.toString().replaceFirst('Exception: ', '');
                  messenger.showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: AppColors.petalWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'Link',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!player.isConnected)
                  TextButton(
                    onPressed: () =>
                        context.read<SpotifyPlayerService>().init(),
                    child: const Text(
                      'Enable player',
                      style: TextStyle(color: Color(0xFF1DB954), fontSize: 11),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.petalWhite.withValues(alpha: 0.54),
                  ),
                  onPressed: () => auth.unlink(),
                  tooltip: 'Unlink',
                ),
              ],
            ),
        ],
      ),
    );
  }
}
