import 'package:flutter/material.dart';

import 'animex_tokens.dart';

/// Shared hover + tap shell for every AnimeX button below.
///
/// All six buttons had the same copy-pasted `MouseRegion` + `GestureDetector`
/// + `_hover` flag. This keeps that behavior (150ms hover lift handled by
/// each button's own `AnimatedContainer`) while each button keeps its exact
/// brand styling — no visual change.
class _HoverTap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool hovered) builder;

  const _HoverTap({required this.builder, this.onTap});

  @override
  State<_HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<_HoverTap> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder(context, _hover),
      ),
    );
  }
}

/// Accent-filled action button (btn-primary).
class AnimeXPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool expanded;

  const AnimeXPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverTap(
      onTap: onTap,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: hover ? AnimeXTokens.accentHover : AnimeXTokens.accent,
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
          boxShadow: hover
              ? [
                  BoxShadow(
                    color: AnimeXTokens.accent.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: dmSansStyle(
                  size: 14,
                  color: Colors.white,
                  weight: FontWeight.w600,
                  letterSpacing: 0.02,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Translucent, blurred secondary button (btn-secondary / btn-more-info).
class AnimeXSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool strong;

  const AnimeXSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverTap(
      onTap: onTap,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: hover
              ? Colors.white.withValues(alpha: 0.13)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
          border: Border.all(
            color: hover
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: AnimeXTokens.textPrimary,
                size: 15,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: dmSansStyle(
                size: 14,
                color: AnimeXTokens.textPrimary,
                weight: strong ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text-only ghost button (btn-ghost).
class AnimeXGhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  const AnimeXGhostButton({
    super.key,
    required this.label,
    this.icon,
    this.color = AnimeXTokens.textSecondary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverTap(
      onTap: onTap,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hover
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: hover ? Colors.white : color,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: dmSansStyle(
                size: 13,
                color: hover ? AnimeXTokens.textPrimary : color,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White "Watch Now" button with a filled play triangle (btn-watch-now).
class AnimeXWatchNowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const AnimeXWatchNowButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _HoverTap(
      onTap: onTap,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: hover ? const Color(0xFFE8E8E8) : Colors.white,
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_arrow_rounded,
              color: AnimeXTokens.bg,
              size: 16,
              fill: 1,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: dmSansStyle(
                size: 13.5,
                color: AnimeXTokens.bg,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Login-style white pill button.
class AnimeXLoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const AnimeXLoginButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverTap(
      onTap: onTap,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: hover ? Colors.white : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AnimeXTokens.bg, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: dmSansStyle(
                size: 13.5,
                color: const Color(0xFF0F0F13),
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small circular icon button (search, back).
class AnimeXIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  const AnimeXIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _HoverTap(
        onTap: onTap,
        builder: (context, hover) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: hover
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
          ),
          child: Icon(
            icon,
            size: 18,
            color: hover ? Colors.white : AnimeXTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
