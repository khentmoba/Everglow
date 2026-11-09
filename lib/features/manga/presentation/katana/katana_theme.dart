import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../data/services/katana_service.dart';

/// Everglow "MangaCelestia — Sakura Noir Sanctuary" black & pink palette
/// used across the manga/manhwa/manhua section: deep velvet-black surfaces
/// paired with hot sakura pink (#FF2E7E) and soft sakura blush (#FF85B3).
abstract final class KatanaColors {
  static const Color background = Color(0xFF060408); // deepest velvet black
  static const Color surface = Color(0xFF0E0912); // sakura noir card
  static const Color surfaceAlt = Color(0xFF170E1D); // elevated noir surface
  static const Color surfaceGlow = Color(0xFF211229); // soft sakura highlight
  static const Color border = Color(0xFF2E1726); // dark sakura hairline
  static const Color borderStrong = Color(0xFF52213B); // highlighted pink line
  static const Color text = Color(0xFFFFF5F8); // crisp sakura-petal white
  static const Color textMuted = Color(0xFFD9B8C7); // blush secondary text
  static const Color textLight = Color(0xFF997586); // quiet dusty-rose text
  static const Color accent = Color(0xFFFF2E7E); // hot sakura pink
  static const Color accentDark = Color(0xFFC9185B); // crimson pink
  static const Color accentSoft = Color(0xFFFF85B3); // soft sakura blush
  static const Color link = Color(0xFFFF85B3); // sakura blush links & chips
  static const Color green = AppColors.success;
  static const Color orange = Color(0xFFFF5C99); // hot-pink flame accent
  static const Color headerDark = Color(0xFF09060C); // noir header base
}

abstract final class KatanaType {
  static TextStyle title = AppTypography.outfitBold.copyWith(
    color: KatanaColors.text,
    fontSize: 16,
    height: 1.25,
  );

  static TextStyle heading = AppTypography.outfitBold.copyWith(
    color: KatanaColors.text,
    fontSize: 22,
    height: 1.2,
  );

  static TextStyle section = AppTypography.outfitBold.copyWith(
    color: KatanaColors.text,
    fontSize: 17,
    height: 1.2,
  );

  static TextStyle body = AppTypography.outfitWhite.copyWith(
    color: KatanaColors.textMuted,
    fontSize: 13.5,
    height: 1.55,
  );

  static TextStyle small = AppTypography.outfitWhite.copyWith(
    color: KatanaColors.textLight,
    fontSize: 12,
  );

  static TextStyle link = AppTypography.outfitWhite.copyWith(
    color: KatanaColors.link,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static TextStyle accent = AppTypography.outfitBold.copyWith(
    color: KatanaColors.accent,
    fontSize: 13,
  );
}

/// A bordered noir card used for every MangaCelestia panel.
class KatanaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadius? radius;

  const KatanaCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color = KatanaColors.surface,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius ?? BorderRadius.circular(12),
        border: Border.all(color: KatanaColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Section header bar with a glowing sakura-pink accent rule.
class KatanaSectionHeader extends StatelessWidget {
  final String title;
  final String? badge;
  final Widget? trailing;
  final Color underline;

  const KatanaSectionHeader({
    super.key,
    required this.title,
    this.badge,
    this.trailing,
    this.underline = KatanaColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [underline, KatanaColors.accentSoft],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitBold.copyWith(
                    color: KatanaColors.text,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
              ),
              if (badge != null &&
                  badge!.isNotEmpty &&
                  MediaQuery.sizeOf(context).width >= 430) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: KatanaColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: KatanaColors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: AppTypography.outfitBold.copyWith(
                      color: KatanaColors.accentSoft,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Primary or outlined Sakura Noir button.
class KatanaButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;

  const KatanaButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.filled = true,
    this.color = KatanaColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    final effective = color ?? KatanaColors.accent;
    final isPrimaryPink = effective == KatanaColors.accent && filled;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: isPrimaryPink
              ? const LinearGradient(
                  colors: [KatanaColors.accent, KatanaColors.accentDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimaryPink
              ? null
              : (filled ? effective : effective.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: filled ? effective : effective.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: filled ? Colors.white : effective),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.outfitBold.copyWith(
                color: filled ? Colors.white : effective,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill chip used for status / genre labels.
class KatanaChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  const KatanaChip({
    super.key,
    required this.label,
    this.color = KatanaColors.accent,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: AppTypography.outfitBold.copyWith(
            color: filled ? Colors.white : color,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

/// Network image wrapper for Manga Katana covers using [AppNetworkImage]
/// with URL validation, auto-retry, and CanvasKit WebGL Alt-Tab safety.
class KatanaNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  const KatanaNetworkImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = KatanaService.proxyImageUrl(url);
    return AppNetworkImage(
      imageUrl: effectiveUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: loadingBuilder != null
          ? Builder(
              builder: (context) =>
                  loadingBuilder!(context, const SizedBox.shrink(), null),
            )
          : null,
      errorWidget: errorBuilder != null
          ? Builder(
              builder: (context) => errorBuilder!(context, 'load failed', null),
            )
          : null,
    );
  }
}
