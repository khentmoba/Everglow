import 'package:flutter/material.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/app_motion.dart';
import 'netflix_colors.dart';

/// Height of the floating desktop/tablet top navbar, excluding the system
/// status inset.
const double kNetflixNavBarHeight = 68;

/// Top inset that page content needs to clear the floating navbar.
///
/// Desktop/tablet uses a top-docked transparent navbar, so headers must
/// start below it. Mobile docks the navbar to the bottom, so only the
/// status-bar inset plus a small breathing gap is needed.
double cinemaTopContentInset(BuildContext context) {
  final topPad = MediaQuery.paddingOf(context).top;
  if (MediaQuery.sizeOf(context).width < 600) return topPad + 12;
  return topPad + kNetflixNavBarHeight + 16;
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
/// Desktop: a top bar that is transparent over the billboard and turns
/// solid once the page scrolls. Mobile: a bottom bar with icon tabs.
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
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) {
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
    return _NetflixTopNav(
      scrolled: scrolled,
      currentIndex: currentIndex,
      links: links,
      onSelect: onSelect,
      onSearchTap: onSearchTap,
      onAccountTap: onAccountTap,
      onBackToDashboard: onBackToDashboard,
      logoText: logoText,
    );
  }
}

class _NetflixTopNav extends StatelessWidget {
  final bool scrolled;
  final int currentIndex;
  final List<NetflixNavLink> links;
  final void Function(int tab, String? browseOptionId) onSelect;
  final VoidCallback? onSearchTap;
  final VoidCallback? onAccountTap;
  final VoidCallback? onBackToDashboard;
  final String logoText;

  const _NetflixTopNav({
    required this.scrolled,
    required this.currentIndex,
    required this.links,
    required this.onSelect,
    this.onSearchTap,
    this.onAccountTap,
    this.onBackToDashboard,
    required this.logoText,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final topPad = MediaQuery.paddingOf(context).top;

    return AnimatedContainer(
      duration: AppMotion.orZero(const Duration(milliseconds: 260)),
      curve: Curves.easeOut,
      height: kNetflixNavBarHeight + topPad,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 48 : 24,
        topPad,
        isDesktop ? 48 : 24,
        0,
      ),
      decoration: BoxDecoration(
        color: scrolled ? NetflixColors.background : Colors.transparent,
        border: scrolled
            ? Border(
                bottom: BorderSide(color: NetflixColors.hairline, width: 0.7),
              )
            : null,
      ),
      child: Row(
        children: [
          // Brand mark.
          Row(
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
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                logoText,
              style: AppTypography.cormorantExtraBold.copyWith(fontSize: isDesktop ? 21 : 18, letterSpacing: 0.4, color: const Color(0xFFF4C2C2)),
              ),
            ],
          ),
          const SizedBox(width: 36),
          Expanded(
            child: Row(
              children: [
                for (final link in links) ...[
                  _TopLink(
                    label: link.label,
                    active: link.tab == currentIndex,
                    onTap: () => onSelect(link.tab, link.browseOptionId),
                  ),
                  const SizedBox(width: 20),
                ],
              ],
            ),
          ),
          if (onBackToDashboard != null) ...[
            _TopAction(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Dashboard',
              onTap: onBackToDashboard!,
            ),
            const SizedBox(width: 6),
          ],
          if (onSearchTap != null) ...[
            _TopAction(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onTap: onSearchTap!,
            ),
            const SizedBox(width: 6),
          ],
          _TopAction(
            icon: Icons.account_circle_outlined,
            tooltip: 'Account',
            onTap: onAccountTap ?? () {},
          ),
        ],
      ),
    );
  }
}

class _TopLink extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TopLink({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_TopLink> createState() => _TopLinkState();
}

class _TopLinkState extends State<_TopLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
         style: AppTypography.outfitHeading.copyWith(fontSize: 14, color: widget.active || _hovered
               ? Colors.white
               : Colors.white.withValues(alpha: 0.72)),
// replaced
        ),
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 24),
        tooltip: tooltip,
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
            style: AppTypography.outfitHeading.copyWith(fontSize: 9.5, color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}
