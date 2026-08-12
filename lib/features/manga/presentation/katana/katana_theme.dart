import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// Light "Manga Katana" palette used across the manga/manhwa/manhua
/// section. Mirrors the look of mangakatana.com (white surfaces, red
/// accents, blue links) while keeping the app's Outfit type family.
abstract final class KatanaColors {
  static const Color background = Color(0xFFF3F4F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFAFAFA);
  static const Color border = Color(0xFFE3E5E9);
  static const Color text = Color(0xFF22252B);
  static const Color textMuted = Color(0xFF5A606B);
  static const Color textLight = Color(0xFF9AA0AA);
  static const Color accent = Color(0xFFDF242F);
  static const Color accentDark = Color(0xFFB91D27);
  static const Color link = Color(0xFF0088CC);
  static const Color green = Color(0xFF16A34A);
  static const Color orange = Color(0xFFFA9008);
  static const Color headerDark = Color(0xFF2A2F3A);
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

/// A bordered white card used for every Katana panel.
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
        borderRadius: radius ?? BorderRadius.circular(10),
        border: Border.all(color: KatanaColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Widget-title bar used at the top of Katana sections.
class KatanaSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Color underline;

  const KatanaSectionHeader({
    super.key,
    required this.title,
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
            color: underline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppTypography.outfitBold.copyWith(
              color: KatanaColors.text,
              fontSize: 18,
              height: 1.2,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Small red primary button in the style of the site's
/// `uk-button-primary`.
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? effective : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
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

/// Network image that prefers rendering through an `<img>` element.
///
/// Manga Katana's cover host doesn't send CORS headers, so byte-fetch
/// decoding fails on the web. Rendering via an HTML image element
/// sidesteps CORS entirely for cover art.
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
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
