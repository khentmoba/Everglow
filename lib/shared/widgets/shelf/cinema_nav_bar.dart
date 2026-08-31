import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_breakpoints.dart';
import 'motion.dart';

/// Navigation item model for the cinema nav bar.
class CinemaNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badge;

  const CinemaNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
}

/// Responsive cinema navigation bar.
///
/// On **desktop & tablet** — renders a sleek top navbar with logo icon,
/// horizontal nav links with icons, and action icons (search, account),
/// inspired by Cineby's floating header.
///
/// On **mobile** — renders a floating pill bottom nav for thumb reach.
class CinemaNavBar extends StatelessWidget {
  final int currentIndex;
  final List<CinemaNavItem> items;
  final ValueChanged<int> onTap;
  final VoidCallback? onSearchTap;
  final String? logoText;
  final VoidCallback? onBackToDashboard;
  final VoidCallback? onAccountTap;

  const CinemaNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.onSearchTap,
    this.logoText,
    this.onBackToDashboard,
    this.onAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    final bp = AppBreakpoint.of(context);
    if (bp == BreakpointSize.mobile) {
      return _CinemaBottomNav(
        currentIndex: currentIndex,
        items: items,
        onTap: onTap,
        onBackToDashboard: onBackToDashboard,
      );
    }
    return _CinemaTopNav(
      currentIndex: currentIndex,
      items: items,
      onTap: onTap,
      onSearchTap: onSearchTap,
      logoText: logoText ?? 'Everglow Cinema',
      onBackToDashboard: onBackToDashboard,
      onAccountTap: onAccountTap,
    );
  }
}

// ── Top navbar (desktop / tablet) ───────────────────────────

class _CinemaTopNav extends StatefulWidget {
  final int currentIndex;
  final List<CinemaNavItem> items;
  final ValueChanged<int> onTap;
  final VoidCallback? onSearchTap;
  final String logoText;
  final VoidCallback? onBackToDashboard;
  final VoidCallback? onAccountTap;

  const _CinemaTopNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.onSearchTap,
    required this.logoText,
    this.onBackToDashboard,
    this.onAccountTap,
  });

  @override
  State<_CinemaTopNav> createState() => _CinemaTopNavState();
}

class _CinemaTopNavState extends State<_CinemaTopNav> {
  bool _headerHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= AppBreakpoint.desktop;

    return MouseRegion(
      onEnter: (_) => setState(() => _headerHovered = true),
      onExit: (_) => setState(() => _headerHovered = false),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 48 : 24,
          MediaQuery.paddingOf(context).top + 4,
          isDesktop ? 48 : 24,
          0,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.animeBackground.withValues(alpha: 0.92),
              AppColors.animeBackground.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            // Back to Dashboard button (couple users)
            if (widget.onBackToDashboard != null)
              _ActionIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Dashboard',
                onTap: widget.onBackToDashboard!,
              ),
            if (widget.onBackToDashboard != null) const SizedBox(width: 8),

            // Logo icon (red play button) + brand text
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: _headerHovered
                    ? [
                        BoxShadow(
                          color: AppTheme.deepRose.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Red play button icon
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.deepRose.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.logoText,
                    style: AppTypography.cormorantExtraBold.copyWith(
                      fontSize: isDesktop ? 22 : 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),

            // Nav links (with icons)
            Row(
              children: List.generate(widget.items.length, (i) {
                final isActive = i == widget.currentIndex;
                return _NavLink(
                  label: widget.items[i].label,
                  icon: widget.items[i].icon,
                  activeIcon: widget.items[i].activeIcon,
                  isActive: isActive,
                  badge: widget.items[i].badge,
                  onTap: () => widget.onTap(i),
                );
              }),
            ),

            const Spacer(),

            // Search icon
            if (widget.onSearchTap != null)
              _ActionIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onTap: widget.onSearchTap!,
              ),

            const SizedBox(width: 8),

            // Account / profile
            _ActionIconButton(
              icon: Icons.account_circle_outlined,
              tooltip: 'Account',
              onTap: widget.onAccountTap ?? () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    this.badge,
    required this.onTap,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (show) => setState(() => _hovered = show),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: ShelfMotion.orZero(ShelfMotion.fast),
            curve: ShelfMotion.easeOutStrong,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppTheme.deepRose.withValues(alpha: 0.12)
                  : (_hovered
                        ? AppTheme.petalWhite.withValues(alpha: 0.05)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isActive ? widget.activeIcon : widget.icon,
                  size: 16,
                  color: widget.isActive
                      ? AppTheme.petalWhite
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 14,
                    fontWeight: widget.isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.isActive
                        ? AppTheme.petalWhite
                        : AppColors.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
                if (widget.badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.badge!,
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.deepRose,
                      ),
                    ),
                  ),
                ],
                if (widget.isActive)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppTheme.deepRose,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (show) => setState(() => _hovered = show),
      child: Tooltip(
        message: widget.tooltip,
        textStyle: AppTypography.outfitBold.copyWith(fontSize: 11),
        decoration: BoxDecoration(
          color: AppTheme.velvet,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: ShelfMotion.orZero(ShelfMotion.fast),
            curve: ShelfMotion.easeOutStrong,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.petalWhite.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.icon,
              color: _hovered ? AppTheme.petalWhite : AppColors.textMuted,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom nav (mobile) ─────────────────────────────────────

class _CinemaBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<CinemaNavItem> items;
  final ValueChanged<int> onTap;
  final VoidCallback? onBackToDashboard;

  const _CinemaBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.onBackToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.animeCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.roseQuartz.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.deepRose.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (onBackToDashboard != null)
                GestureDetector(
                  onTap: onBackToDashboard,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.petalWhite,
                      size: 20,
                    ),
                  ),
                ),
              ...List.generate(items.length, (i) {
                final item = items[i];
                final active = i == currentIndex;
                return _BottomNavItem(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  isActive: active,
                  badge: item.badge,
                  onTap: () => onTap(i),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ShelfMotion.orZero(ShelfMotion.medium),
          curve: ShelfMotion.easeOutStrong,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.deepRose.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 20,
                color: isActive ? AppTheme.petalWhite : AppColors.textMuted,
              ),
              if (isActive) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.outfitHeading.copyWith(fontSize: 11),
                ),
              ],
              if (badge != null && isActive) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRose,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
