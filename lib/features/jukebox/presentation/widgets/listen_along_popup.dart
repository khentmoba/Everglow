import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/music_status.dart';
import '../../data/services/spotify_auth_service.dart';
import '../../data/services/spotify_player_service.dart';
import '../../data/services/spotify_resolve_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import 'spotify_embed_view.dart';

class ListenAlongPopup extends StatefulWidget {
  final MusicStatus status;

  const ListenAlongPopup({super.key, required this.status});

  @override
  State<ListenAlongPopup> createState() => _ListenAlongPopupState();
}

class _ListenAlongPopupState extends State<ListenAlongPopup> {
  late MusicStatus _status;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    // Phase 0: resolve real Spotify ID for embed (no auth needed beyond Firebase)
    if (!_status.hasSpotifyTrack && _status.trackName != 'Silent Night') {
      _resolving = true;
      SpotifyResolveService().resolve(_status).then((resolved) {
        if (mounted) setState(() { _status = resolved; _resolving = false; });
      });
    }
  }

  Future<void> _launchSpotify() async {
    final Uri url = Uri.parse(_status.resolvedSpotifyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _playInEverglow() async {
    if (!_status.hasSpotifyTrack) return;
    final player = context.read<SpotifyPlayerService>();
    await player.init();
    await player.playTrack(_status.spotifyTrackId!);
  }

  @override
  Widget build(BuildContext context) {
    final isLinked = context.watch<SpotifyAuthService>().isLinked;
    final hasTrack = _status.hasSpotifyTrack;
    return Dialog(
      backgroundColor: AppTheme.velvet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.2), width: 1.5),
        ),
        padding: const EdgeInsets.all(32.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Album art OR embedded player
              if (hasTrack && kIsWeb)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      // Still show large art for vibe
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: AppTheme.deepRose.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _status.imageUrl != null
                              ? Image.network(_status.imageUrl!, fit: BoxFit.cover)
                              : Container(color: AppTheme.twilight, child: const Icon(Icons.music_note, size: 80, color: AppTheme.roseQuartz)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Embed (300x80 compact Spotify player) - works for free users (30s preview) & Premium (full)
                      SpotifyEmbedView(trackId: _status.spotifyTrackId!),
                    ],
                  ),
                )
              else
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppTheme.deepRose.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _status.imageUrl != null
                        ? Image.network(_status.imageUrl!, fit: BoxFit.cover)
                        : Container(color: AppTheme.twilight, child: const Icon(Icons.music_note, size: 80, color: AppTheme.roseQuartz)),
                  ),
                ),
              if (_resolving) ...[
                const SizedBox(height: 12),
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.blushGold)),
              ],
              const SizedBox(height: 24),
              Text(_status.trackName, textAlign: TextAlign.center, style: AppTypography.cormorantBold.copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              Text(_status.artistName, textAlign: TextAlign.center, style: AppTypography.outfitWhite.copyWith(fontSize: 16, color: AppTheme.blushGold, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(_status.albumName, textAlign: TextAlign.center, style: AppTypography.outfitWhite.copyWith(fontSize: 13, color: AppTheme.petalWhite.withValues(alpha: 0.7))),
              const SizedBox(height: 24),
              // Primary: Play in Everglow (Web Playback SDK) - Duo Premium
              if (hasTrack)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLinked ? _playInEverglow : null,
                    icon: Icon(isLinked ? Icons.play_circle_fill : Icons.link_rounded, size: 22, color: AppTheme.petalWhite),
                    label: Text(isLinked ? 'Play in Everglow' : 'Link Spotify to play here',
                        style: AppTypography.outfitWhite.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLinked ? AppTheme.deepRose : AppTheme.deepRose.withValues(alpha: 0.5),
                      foregroundColor: AppTheme.petalWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                  ),
                ),
              if (!isLinked && hasTrack) ...[
                const SizedBox(height: 8),
                Text('Connect Spotify in Jukebox to enable in-app playback (Duo ✓)', textAlign: TextAlign.center, style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.55))),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _launchSpotify,
                  icon: const Icon(Icons.open_in_new_rounded, size: 20, color: AppTheme.petalWhite),
                  label: Text('Open in Spotify', style: AppTypography.outfitWhite.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.twilight,
                    foregroundColor: AppTheme.petalWhite,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    side: BorderSide(color: AppTheme.blushGold.withValues(alpha: 0.18)),
                    elevation: 0,
                  ),
                ),
              ),
              // Preview fallback for non-Premium via just_audio if available
              if (_status.previewUrl != null && !hasTrack) ...[
                const SizedBox(height: 8),
                Text('30s preview available', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.55))),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz.withValues(alpha: 0.6))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
