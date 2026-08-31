import 'package:flutter/material.dart';

import 'animex_tokens.dart';

/// Accent-filled action button (btn-primary).
class AnimeXPrimaryButton extends StatefulWidget {
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
  State<AnimeXPrimaryButton> createState() => _AnimeXPrimaryButtonState();
}

class _AnimeXPrimaryButtonState extends State<AnimeXPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? AnimeXTokens.accentHover : AnimeXTokens.accent,
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
            boxShadow: _hover
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
            mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 15),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
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
      ),
    );
  }
}

/// Translucent, blurred secondary button (btn-secondary / btn-more-info).
class AnimeXSecondaryButton extends StatefulWidget {
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
  State<AnimeXSecondaryButton> createState() => _AnimeXSecondaryButtonState();
}

class _AnimeXSecondaryButtonState extends State<AnimeXSecondaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: 0.13)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
            border: Border.all(
              color: _hover
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: widget.strong
                      ? AnimeXTokens.textPrimary
                      : AnimeXTokens.textPrimary,
                  size: 15,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: dmSansStyle(
                  size: 14,
                  color: AnimeXTokens.textPrimary,
                  weight: widget.strong ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text-only ghost button (btn-ghost).
class AnimeXGhostButton extends StatefulWidget {
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
  State<AnimeXGhostButton> createState() => _AnimeXGhostButtonState();
}

class _AnimeXGhostButtonState extends State<AnimeXGhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 14,
                  color: _hover ? Colors.white : widget.color,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: dmSansStyle(
                  size: 13,
                  color: _hover ? AnimeXTokens.textPrimary : widget.color,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White "Watch Now" button with a filled play triangle (btn-watch-now).
class AnimeXWatchNowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const AnimeXWatchNowButton({super.key, required this.label, this.onTap});

  @override
  State<AnimeXWatchNowButton> createState() => _AnimeXWatchNowButtonState();
}

class _AnimeXWatchNowButtonState extends State<AnimeXWatchNowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFE8E8E8) : Colors.white,
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
                widget.label,
                style: dmSansStyle(
                  size: 13.5,
                  color: AnimeXTokens.bg,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Login-style white pill button.
class AnimeXLoginButton extends StatefulWidget {
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
  State<AnimeXLoginButton> createState() => _AnimeXLoginButtonState();
}

class _AnimeXLoginButtonState extends State<AnimeXLoginButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? Colors.white : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: AnimeXTokens.bg, size: 14),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: dmSansStyle(
                  size: 13.5,
                  color: const Color(0xFF0F0F13),
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small circular icon button (search, back).
class AnimeXIconButton extends StatefulWidget {
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
  State<AnimeXIconButton> createState() => _AnimeXIconButtonState();
}

class _AnimeXIconButtonState extends State<AnimeXIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _hover
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hover ? Colors.white : AnimeXTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
