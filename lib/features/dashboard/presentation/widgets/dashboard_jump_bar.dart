import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_keyboard_activation.dart';

class DashboardJumpBar extends StatelessWidget {
  const DashboardJumpBar({super.key, required this.onJump});
  final void Function(String id) onJump;

  @override
  Widget build(BuildContext context) {
    final items = [
      const JumpItem(
        'Today',
        Icons.auto_awesome_rounded,
        AppColors.auroraGold,
        'coming-up',
      ),
      const JumpItem(
        'Watching',
        Icons.play_circle_rounded,
        AppColors.auroraRose,
        'watching',
      ),
      const JumpItem(
        'Shelves',
        Icons.local_movies_rounded,
        AppColors.softLavender,
        'shelves',
      ),
      const JumpItem(
        'Timeline',
        Icons.timeline_rounded,
        AppColors.blushGold,
        'timeline',
      ),
      const JumpItem(
        'Moments',
        Icons.favorite_rounded,
        AppColors.deepRose,
        'moments',
      ),
    ];
    return Semantics(
      label: 'Jump to section',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: 0.52),
          borderRadius: AppRadius.radiusXl,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 1,
                  color: AppColors.blushGold.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 10),
                Text(
                  'JUMP TO',
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.8,
                    color: AppColors.blushGold.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.moonlight.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((it) {
                return JumpChip(item: it, onJump: onJump);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class JumpItem {
  final String label;
  final IconData icon;
  final Color hue;
  final String targetId;
  const JumpItem(this.label, this.icon, this.hue, this.targetId);
}

class JumpChip extends StatefulWidget {
  const JumpChip({super.key, required this.item, required this.onJump});
  final JumpItem item;
  final void Function(String) onJump;
  @override
  State<JumpChip> createState() => _JumpChipState();
}

class _JumpChipState extends State<JumpChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return Semantics(
      button: true,
      label: 'Jump to ${it.label}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: EverglowKeyboardActivation(
          onActivate: () => widget.onJump(it.targetId),
          child: GestureDetector(
            onTap: () => widget.onJump(it.targetId),
            child: AnimatedContainer(
              duration: AppMotion.orZero(const Duration(milliseconds: 180)),
              curve: AppMotion.easeOutStrong,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    it.hue.withValues(alpha: _hovered ? 0.22 : 0.12),
                    it.hue.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: it.hue.withValues(alpha: _hovered ? 0.45 : 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: it.hue.withValues(alpha: 0.18),
                      border: Border.all(color: it.hue.withValues(alpha: 0.35)),
                    ),
                    child: Icon(it.icon, size: 12, color: it.hue),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    it.label,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 11,
                      color: AppColors.petalWhite.withValues(
                        alpha: _hovered ? 0.95 : 0.82,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
