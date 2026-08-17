import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/music_status.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

class ListenAlongPopup extends StatelessWidget {
  final MusicStatus status;

  const ListenAlongPopup({super.key, required this.status});

  Future<void> _launchSpotify() async {
    final Uri url = Uri.parse(status.spotifyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.velvet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.blushGold.withValues(alpha: 0.2), width: 1.5),
        ),
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large Album Art
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepRose.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: status.imageUrl != null
                    ? Image.network(status.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: AppTheme.twilight,
                        child: const Icon(Icons.music_note, size: 80, color: AppTheme.roseQuartz),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              status.trackName,
              textAlign: TextAlign.center,
              style: AppTypography.cormorantBold.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              status.artistName,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(fontSize: 16, color: AppTheme.blushGold, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              status.albumName,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(fontSize: 13, color: AppTheme.petalWhite.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _launchSpotify,
              icon: const Icon(Icons.play_circle_fill, size: 24, color: AppTheme.petalWhite),
              label: Text(
                'Listen on Spotify',
                style: AppTypography.outfitWhite.copyWith(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepRose,
                foregroundColor: AppTheme.petalWhite,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: AppTypography.outfitWhite.copyWith(color: AppTheme.roseQuartz.withValues(alpha: 0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
