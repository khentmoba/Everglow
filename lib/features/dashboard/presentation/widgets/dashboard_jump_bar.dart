import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_keyboard_activation.dart';

/// Distilled zone jump bar — 4 zones instead of 5 scattered anchors.
/// Today / Together / Our World / Play
/// Each chip scrolls to a DashboardZoneHeader anchor. Replaces the
/// previous 5-item bar (Today/Watching/Shelves/Timeline/Moments) which
/// leaked shelf concerns back onto the dashboard.
class DashboardJumpBar extends StatelessWidget {
  const DashboardJumpBar({super.key, required this.onJump});
  final void Function(String id) onJump;

  @override
  Widget build(BuildContext context) {
    final items = [
      const JumpItem('Today', Icons.wb_twilight_rounded, AppColors.auroraGold, 'zone-today'),
      const JumpItem('Together', Icons.favorite_rounded, AppColors.auroraRose, 'zone-together'),
      const JumpItem('Our World', Icons.public_rounded, AppColors.auroraTeal, 'zone-world'),
      const JumpItem('Play', Icons.videogame_asset_rounded, AppColors.softLavender, 'zone-play'),
    ];
    return Semantics(
      label: 'Jump to zone',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 22, height: 1, color: AppColors.blushGold.withValues(alpha: 0.30)),
                const SizedBox(width: 10),
                Text(
                  'JUMP TO',
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: AppColors.blushGold.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: AppColors.moonlight.withValues(alpha: 0.06))),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((it) => JumpChip(item: it, onJump: onJump)).toList(),
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
      label: 'Jump to ',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: EverglowKeyboardActivation(
          onActivate: () => widget.onJump(it.targetId),
          child: GestureDetector(
            onTap: () => widget.onJump(it.targetId),
            child: AnimatedContainer(
              duration: AppMotion.orZero(const Duration(milliseconds: 160)),
              curve: AppMotion.easeOutStrong,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: _hovered ? it.hue.withValues(alpha: 0.16) : it.hue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: it.hue.withValues(alpha: _hovered ? 0.38 : 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: it.hue.withValues(alpha: 0.16),
                      border: Border.all(color: it.hue.withValues(alpha: 0.32)),
                    ),
                    child: Icon(it.icon, size: 12, color: it.hue),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    it.label,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 11,
                      color: AppColors.petalWhite.withValues(alpha: _hovered ? 0.92 : 0.78),
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
