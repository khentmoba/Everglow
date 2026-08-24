import 'package:flutter/material.dart';

import 'animex_controller.dart';
import 'animex_tokens.dart';

/// Site footer for the anime section, matching the reference layout:
/// wordmark + tagline, legal/social links and copyright.
class AnimeXFooter extends StatelessWidget {
  final AnimeXController controller;

  const AnimeXFooter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      decoration: const BoxDecoration(
        color: AnimeXTokens.surface,
        border: Border(top: BorderSide(color: AnimeXTokens.border)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AnimeXTokens.pageMaxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            final links = <Widget>[
              _FooterLink(label: 'DMCA', onTap: () => controller.openDmca()),
              const SizedBox(width: 20),
              _FooterLink(
                label: 'Home',
                onTap: () => controller.goTo(AnimexPage.home),
              ),
              const SizedBox(width: 20),
              Text(
                '© 2026 Everglow. For entertainment purposes only.',
                style: dmSansStyle(size: 12, color: AnimeXTokens.textMuted),
              ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'EVER',
                      style: bebasStyle(
                        size: 19,
                        color: AnimeXTokens.textPrimary,
                      ),
                    ),
                    Text(
                      'GLOW',
                      style: bebasStyle(size: 19, color: AnimeXTokens.accent),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '— anime section',
                      style: dmSansStyle(
                        size: 12,
                        color: AnimeXTokens.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: links,
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: links,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: dmSansStyle(
            size: 13,
            color: AnimeXTokens.textMuted,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
