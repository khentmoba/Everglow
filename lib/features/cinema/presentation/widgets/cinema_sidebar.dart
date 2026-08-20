import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_typography.dart';
import 'netflix/netflix_colors.dart';

/// Collapsible sidebar for the Cinema section.
///
/// - Desktop (≥1024) : persistent rail. Expanded = 260px with labels,
///   collapsed = 72px icon-only. The rail itself hosts the toggle.
/// - Mobile (<1024)  : rendered as an overlay drawer by the parent;
///   this widget still paints the 280px panel itself.
///   The parent is responsible for the scrim + slide animation.
///
/// Contains a dedicated **Anime** entry that routes to `/anime` so
/// cinema-only profiles (breyan / octagram) can jump between the two
/// libraries without touching the dashboard.
///
/// When [isAnimeActive] is true the sidebar is rendered for the anime
/// route: the Anime card appears active, a **Cinema** back-entry is
/// shown, and all browse taps are still routed back to `/cinema`.
class CinemaSidebar extends StatelessWidget {
  final int currentIndex;
  final String? activeBrowseOption;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final void Function(int tab, String? browseOptionId) onSelect;
  final VoidCallback onAnimeTap;
  final VoidCallback? onDashboardTap;
  final VoidCallback onLogout;
  final String userName;
  final bool isCinemaOnlyUser;
  final bool isAnimeActive;
  final VoidCallback? onCinemaTap;

  const CinemaSidebar({
    super.key,
    required this.currentIndex,
    this.activeBrowseOption,
    required this.isCollapsed,
    required this.onToggle,
    required this.onSelect,
    required this.onAnimeTap,
    this.onDashboardTap,
    required this.onLogout,
    required this.userName,
    required this.isCinemaOnlyUser,
    this.isAnimeActive = false,
    this.onCinemaTap,
  });

  bool get _isMoviesActive =>
      currentIndex == 2 && activeBrowseOption == 'collection-movies';
  bool get _isTvActive =>
      currentIndex == 2 && activeBrowseOption == 'collection-tv';
  bool get _isNewActive =>
      currentIndex == 2 && activeBrowseOption == 'collection-new';
  bool get _isBrowseActive =>
      currentIndex == 2 && activeBrowseOption == null;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A14),
        border: Border(
          right: BorderSide(color: NetflixColors.hairline, width: 0.8),
        ),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            height: kToolbarHeight + topPad,
            padding: EdgeInsets.only(
              top: topPad,
              left: isCollapsed ? 0 : 16,
              right: isCollapsed ? 0 : 8,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: isCollapsed
                ? Center(
                    child: _CollapseButton(
                      isCollapsed: true,
                      onTap: onToggle,
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isAnimeActive
                              ? const Color(0xFFC2185B)
                              : NetflixColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAnimeActive
                              ? Icons.auto_awesome_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isAnimeActive ? 'Anime' : 'Cinema',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cormorantExtraBold.copyWith(
                            fontSize: 17,
                            letterSpacing: 0.4,
                            color: const Color(0xFFF4C2C2),
                          ),
                        ),
                      ),
                      _CollapseButton(
                        isCollapsed: false,
                        onTap: onToggle,
                      ),
                    ],
                  ),
          ),

          // ── Nav ─────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                if (!isCollapsed) ...[
                  _SectionLabel(label: 'Browse'),
                  const SizedBox(height: 6),
                ],
                _SidebarEntry(
                  isCollapsed: isCollapsed,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  active: currentIndex == 0 && activeBrowseOption == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(0, null);
                  },
                ),
                _SidebarEntry(
                  isCollapsed: isCollapsed,
                  icon: Icons.search_rounded,
                  activeIcon: Icons.search_rounded,
                  label: 'Search',
                  active: currentIndex == 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(1, null);
                  },
                ),
                _SidebarEntry(
                  isCollapsed: isCollapsed,
                  icon: Icons.grid_view_rounded,
                  activeIcon: Icons.grid_view_rounded,
                  label: 'Browse All',
                  active: _isBrowseActive,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(2, null);
                  },
                ),
                _SidebarEntry(
                  isCollapsed: isCollapsed,
                  icon: Icons.movie_outlined,
                  activeIcon: Icons.movie_rounded,
                  label: 'Movies',
                  active: _isMoviesActive,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(2, 'collection-movies');
                  },
                ),
                _SidebarEntry(
                  isCollapsed: isCollapsed,
                  icon: Icons.live_tv_outlined,
                  activeIcon: Icons.live_tv_rounded,
                  label: 'TV Shows',
                  active: _isTvActive,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(2, 'collection-tv');
                  },
                ),
                _SidebarEntry(
                  isCollapsed: isCollapsed,
                  icon: Icons.local_fire_department_outlined,
                  activeIcon: Icons.local_fire_department_rounded,
                  label: 'New & Popular',
                  active: _isNewActive,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(2, 'collection-new');
                  },
                ),
                const SizedBox(height: 4),
                _SidebarEntry(
                  isCollapsed: isCollapsed,
                  icon: Icons.bookmark_border_rounded,
                  activeIcon: Icons.bookmark_rounded,
                  label: 'My List',
                  active: currentIndex == 3,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(3, null);
                  },
                ),
                _SidebarEntry(
                  isCollapsed: isCollapsed,
                  icon: Icons.favorite_outline_rounded,
                  activeIcon: Icons.favorite_rounded,
                  label: 'Watch Together',
                  active: currentIndex == 4,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(4, null);
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),

                // ── Anime / Cinema cross-link ────────────────────────
                if (!isCollapsed) ...[
                  _SectionLabel(
                    label: isAnimeActive ? 'Anime Discover' : 'Discover',
                  ),
                  const SizedBox(height: 6),
                ],
                if (isAnimeActive) ...[
                  _AnimeEntry(
                    isCollapsed: isCollapsed,
                    active: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onAnimeTap();
                    },
                  ),
                  const SizedBox(height: 8),
                  _CinemaBackEntry(
                    isCollapsed: isCollapsed,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (onCinemaTap != null) {
                        onCinemaTap!();
                      } else {
                        onSelect(0, null);
                      }
                    },
                  ),
                ] else ...[
                  _AnimeEntry(
                    isCollapsed: isCollapsed,
                    active: false,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onAnimeTap();
                    },
                  ),
                ],

                if (onDashboardTap != null) ...[
                  const SizedBox(height: 8),
                  if (!isCollapsed) ...[
                    _SectionLabel(label: 'Everglow'),
                    const SizedBox(height: 6),
                  ],
                  _SidebarEntry(
                    isCollapsed: isCollapsed,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    active: false,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onDashboardTap!.call();
                    },
                  ),
                ],
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
              color: Colors.white.withValues(alpha: 0.02),
            ),
            padding: EdgeInsets.fromLTRB(
              isCollapsed ? 8 : 12,
              12,
              isCollapsed ? 8 : 12,
              12 + MediaQuery.paddingOf(context).bottom * 0.4,
            ),
            child: isCollapsed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _UserAvatar(name: userName, size: 36),
                      const SizedBox(height: 10),
                      Tooltip(
                        message: 'Logout',
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onLogout();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: Color(0xFFB9A9C2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          _UserAvatar(name: userName, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName.isEmpty ? 'Guest' : userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.outfitHeading.copyWith(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  isCinemaOnlyUser
                                      ? 'Cinema access'
                                      : 'Member',
                                  style: AppTypography.outfitMuted.copyWith(
                                    fontSize: 11,
                                    color: NetflixColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tooltip(
                            message: 'Hide sidebar',
                            child: InkWell(
                              onTap: onToggle,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.chevron_left_rounded,
                                  size: 18,
                                  color: Color(0xFFB9A9C2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _FooterButton(
                          icon: Icons.logout_rounded,
                          label: 'Logout',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onLogout();
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onTap;
  const _CollapseButton({required this.isCollapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCollapsed
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isCollapsed
                ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                : null,
          ),
          child: Icon(
            isCollapsed
                ? Icons.chevron_right_rounded
                : Icons.chevron_left_rounded,
            size: 20,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 2, top: 4),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.outfitHeading.copyWith(
          fontSize: 10,
          letterSpacing: 1.1,
          color: Colors.white.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

class _SidebarEntry extends StatefulWidget {
  final bool isCollapsed;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SidebarEntry({
    required this.isCollapsed,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  State<_SidebarEntry> createState() => _SidebarEntryState();
}

class _SidebarEntryState extends State<_SidebarEntry> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final bg = active
        ? Colors.white.withValues(alpha: 0.08)
        : _hovered
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.transparent;
    final iconColor = active
        ? Colors.white
        : Colors.white.withValues(alpha: 0.62);
    final textColor = active
        ? Colors.white
        : Colors.white.withValues(alpha: 0.72);

    final content = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                : null,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 0 : 10,
          ),
          child: widget.isCollapsed
              ? Center(
                  child: Icon(
                    active ? widget.activeIcon : widget.icon,
                    size: 20,
                    color: iconColor,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      active ? widget.activeIcon : widget.icon,
                      size: 19,
                      color: iconColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: 13.2,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (active)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: NetflixColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );

    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Tooltip(message: widget.label, child: content),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: content,
    );
  }
}

class _AnimeEntry extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onTap;
  final bool active;
  const _AnimeEntry({
    required this.isCollapsed,
    required this.onTap,
    this.active = false,
  });
  @override
  State<_AnimeEntry> createState() => _AnimeEntryState();
}

class _AnimeEntryState extends State<_AnimeEntry> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final isActive = widget.active;
    if (widget.isCollapsed) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: isActive ? 'Anime • You are here' : 'Anime',
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _hovered
                      ? const [Color(0xFFC2185B), Color(0xFF8E2F5A)]
                      : const [Color(0xFFB3124A), Color(0xFF7A2442)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.10),
                  width: isActive ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC2185B).withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                  if (isActive)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.10),
                      blurRadius: 8,
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  if (isActive)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF7A2442),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _hovered
                  ? const [Color(0xFFD11A5E), Color(0xFF9A2E58)]
                  : const [Color(0xFFC2185B), Color(0xFF7A2442)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.10),
              width: isActive ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC2185B).withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Anime',
                          style: AppTypography.outfitHeading.copyWith(
                            fontSize: 13.5,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive ? 'You are here' : 'Movies & series',
                      style: AppTypography.outfitMuted.copyWith(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isActive ? 'Active' : 'Go',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      isActive
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CinemaBackEntry extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onTap;
  const _CinemaBackEntry({required this.isCollapsed, required this.onTap});
  @override
  State<_CinemaBackEntry> createState() => _CinemaBackEntryState();
}

class _CinemaBackEntryState extends State<_CinemaBackEntry> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: 'Back to Cinema',
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 42,
              decoration: BoxDecoration(
                color: _hovered
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.movie_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: NetflixColors.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cinema',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 13.5,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Back to movies & TV',
                      style: AppTypography.outfitMuted.copyWith(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.62),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Go',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _UserAvatar({required this.name, required this.size});
  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC2185B), Color(0xFF7A2442)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Center(
        child: Text(
          letter,
          style: AppTypography.outfitHeading.copyWith(
            fontSize: size * 0.42,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFB9A9C2)),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 12.5,
                color: const Color(0xFFB9A9C2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
