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
/// The redundant top bar has been removed — the sidebar is the single
/// source of primary nav. All widths now only clear the status-bar inset
/// plus a small breathing gap.
double cinemaTopContentInset(BuildContext context) {
  final topPad = MediaQuery.paddingOf(context).top;
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
/// The redundant desktop top bar has been removed — the sidebar is the
/// single source of primary nav. This widget now only renders the mobile
/// bottom bar (used as [Scaffold.bottomNavigationBar] on narrow layouts).
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
      items: mobileItems ??
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
            style: AppTypography.outfitHeading.copyWith(fontSize: 9.5, color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}
