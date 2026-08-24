import 'package:flutter/material.dart';

import 'animex_controller.dart';
import 'animex_tokens.dart';

/// DMCA / takedown notice page for the anime section.
class AnimeXDmcaPage extends StatelessWidget {
  final AnimeXController controller;

  const AnimeXDmcaPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 64),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: controller.closeDetail,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                  border: Border.all(color: AnimeXTokens.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 13,
                      color: AnimeXTokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Back',
                      style: dmSansStyle(
                        size: 12.5,
                        color: AnimeXTokens.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'DMCA',
          style: bebasStyle(size: 36, color: AnimeXTokens.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Copyright & Takedown Notice',
          style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
        ),
        const SizedBox(height: 24),
        Text(
          'Everglow\'s anime section is a private, personal library built for '
          'Khent & Clair. It does not host video files: playback streams from '
          'public third-party embed providers, and all artwork, titles and '
          'metadata belong to their respective owners.',
          style: interBodyStyle(size: 14, height: 1.65),
        ),
        const SizedBox(height: 20),
        Text(
          'If you believe content shown here infringes your copyright, please '
          'contact us with the exact title, episode and embed provider, and we '
          'will remove or disable access to the material as soon as possible.',
          style: interBodyStyle(size: 14, height: 1.65),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
            border: Border.all(color: AnimeXTokens.border),
          ),
          child: Text(
            'Notice: Everglow is a personal project with no advertising and '
            'no monetization. All streaming happens inside third-party embeds '
            'provided by external platforms.',
            style: dmSansStyle(
              size: 12.5,
              color: AnimeXTokens.textSecondary,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
