import 'package:flutter/material.dart';
import '../../../../../core/theme/app_typography.dart';
import 'netflix_colors.dart';

/// Height of the floating desktop/tablet top navbar, excluding the system
/// status inset.
///
/// Kept for backwards-compat / tests; the top bar was removed in favor of
/// the persistent sidebar, so this constant is no longer added to the
/// content inset.
const double kNetflixNavBarHeight = 68;

/// Top inset that page content needs to clear the floating navbar.
///
/// Non-hero pages need to clear the overlaying desktop catalog bar.
double cinemaTopContentInset(BuildContext context) {
  final topPad = MediaQuery.paddingOf(context).top;
  if (MediaQuery.sizeOf(context).width >= 1024) {
    return topPad + kToolbarHeight + 20;
  }
  if (MediaQuery.sizeOf(context).width < 600) return topPad + 12;
  return topPad + 16;
}

/// A navigation link for the cinema top/bottom bars.
class NetflixNavLink {
  final String label;
  final int tab;

  /// Optional browse filter to seed when this link opens the Browse tab.
  final String? browseOptionId;

  const NetflixNavLink(this.label, this.tab, [this.browseOptionId]);
}

/// Bottom-bar entry for mobile.
class NetflixMobileItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int tab;
  final String? browseOptionId;

  const NetflixMobileItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.tab,
    this.browseOptionId,
  });
}

/// Netflix-style cinema navigation.
///
/// Desktop renders a transparent-to-solid top bar. Mobile renders the
/// bottom bar used as [Scaffold.bottomNavigationBar] on narrow layouts.
class NetflixNavBar extends StatelessWidget {
  final bool scrolled;
  final int currentIndex;
  final List<NetflixNavLink> links;
  final List<NetflixMobileItem>? mobileItems;
  final void Function(int tab, String? browseOptionId) onSelect;
  final VoidCallback? onSearchTap;
  final VoidCallback? onAccountTap;
  final VoidCallback? onBackToDashboard;
  final String logoText;

  const NetflixNavBar({
    super.key,
    required this.scrolled,
    required this.currentIndex,
    required this.links,
    required this.onSelect,
    this.mobileItems,
    this.onSearchTap,
    this.onAccountTap,
    this.onBackToDashboard,
    this.logoText = 'Everglow Cinema',
  });

  @override
  Widget build(BuildContext context) {
    // Top bar removed — always render the bottom bar variant.
    // Desktop layouts don’t use this widget at all (they show the
    // persistent [CinemaSidebar] instead); mobile/tablet layouts mount
    // it as bottomNavigationBar.
    return _NetflixBottomNav(
      currentIndex: currentIndex,
      items:
          mobileItems ??
          const [
            NetflixMobileItem(
              label: 'Home',
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              tab: 0,
            ),
            NetflixMobileItem(
              label: 'New & Popular',
              icon: Icons.local_fire_department_outlined,
              activeIcon: Icons.local_fire_department_rounded,
              tab: 2,
            ),
            NetflixMobileItem(
              label: 'My List',
              icon: Icons.bookmark_border_rounded,
              activeIcon: Icons.bookmark_rounded,
              tab: 3,
            ),
            NetflixMobileItem(
              label: 'Search',
              icon: Icons.search_rounded,
              activeIcon: Icons.search_rounded,
              tab: 1,
            ),
          ],
      onSelect: onSelect,
    );
  }
}

/// Transparent cinema top bar for desktop widths.
///
/// Primary catalog navigation follows the streaming-service model; the
/// trailing controls are Everglow's application-level destinations.
class NetflixCinemaTopBar extends StatelessWidget {
  final int currentIndex;
  final List<NetflixNavLink> links;
  final void Function(int tab, String? browseOptionId) onSelect;
  final VoidCallback onAnimeTap;
  final VoidCallback? onDashboardTap;
  final VoidCallback onLogout;
  final String userName;
  final bool scrolled;

  const NetflixCinemaTopBar({
    super.key,
    required this.currentIndex,
    required this.links,
    required this.onSelect,
    required this.onAnimeTap,
    this.onDashboardTap,
    required this.onLogout,
    required this.userName,
    this.scrolled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scrolled
          ? Colors.black.withValues(alpha: 0.92)
          : Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 48),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: NetflixColors.hairline.withValues(
                  alpha: scrolled ? 1 : 0,
                ),
              ),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onDashboardTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: NetflixColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Everglow',
                            style: AppTypography.outfitHeading.copyWith(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: '  CINEMA',
                            style: AppTypography.outfitHeading.copyWith(
                              fontSize: 11,
                              color: NetflixColors.accent,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Row(
                  children: [
                    for (final link in links)
                      Padding(
                        padding: const EdgeInsets.only(right: 22),
                        child: _TopBarLink(
                          label: link.label,
                          active: link.tab == currentIndex,
                          onTap: () => onSelect(link.tab, link.browseOptionId),
                        ),
                      ),
                  ],
                ),
              ),
              _ProfileButton(
                userName: userName,
                onLogout: onLogout,
                onAnimeTap: onAnimeTap,
                onDashboardTap: onDashboardTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarLink extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TopBarLink({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_TopBarLink> createState() => _TopBarLinkState();
}

class _TopBarLinkState extends State<_TopBarLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active || _hovered
        ? Colors.white
        : Colors.white.withValues(alpha: .72);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.active || _hovered
                    ? NetflixColors.accent
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            widget.label,
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 14,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final String userName;
  final VoidCallback onLogout;
  final VoidCallback onAnimeTap;
  final VoidCallback? onDashboardTap;

  const _ProfileButton({
    required this.userName,
    required this.onLogout,
    required this.onAnimeTap,
    this.onDashboardTap,
  });

  @override
  Widget build(BuildContext context) {
    final letter = userName.isEmpty ? '?' : userName[0].toUpperCase();
    return PopupMenuButton<String>(
      tooltip: 'Account',
      color: NetflixColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        if (value == 'dashboard') onDashboardTap?.call();
        if (value == 'anime') onAnimeTap.call();
        if (value == 'logout') onLogout.call();
      },
      itemBuilder: (context) => [
        if (onDashboardTap != null)
          const PopupMenuItem(value: 'dashboard', child: Text('Dashboard')),
        const PopupMenuItem(value: 'anime', child: Text('Anime')),
        const PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          shape: BoxShape.circle,
          border: Border.all(color: NetflixColors.hairline),
        ),
        child: Text(
          letter,
          style: AppTypography.outfitHeading.copyWith(fontSize: 13),
        ),
      ),
    );
  }
}

class _NetflixBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<NetflixMobileItem> items;
  final void Function(int tab, String? browseOptionId) onSelect;

  const _NetflixBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NetflixColors.background,
        border: Border(top: BorderSide(color: NetflixColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: _MobileTab(
                    item: item,
                    active: item.tab == currentIndex,
                    onTap: () => onSelect(item.tab, item.browseOptionId),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileTab extends StatelessWidget {
  final NetflixMobileItem item;
  final bool active;
  final VoidCallback onTap;

  const _MobileTab({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? item.activeIcon : item.icon,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
            size: 23,
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 10.5,
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
