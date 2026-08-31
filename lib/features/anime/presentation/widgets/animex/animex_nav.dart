import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/services/animex_stores.dart';
import '../../../../../core/services/auth_service.dart';

import 'animex_buttons.dart';
import 'animex_controller.dart';
import 'animex_tokens.dart';

/// Fixed top header for the anime section (desktop / tablet).
class AnimeXTopHeader extends StatelessWidget {
  final AnimeXController controller;
  final VoidCallback onSearch;

  const AnimeXTopHeader({
    super.key,
    required this.controller,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';
    final isCoupleUser = auth.isCoupleUser;
    final isCinemaOnlyUser = auth.isCinemaOnlyUser;
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final items = const [
      (AnimexPage.home, 'Home', Icons.house_outlined),
      (AnimexPage.schedule, 'Schedule', Icons.calendar_month_outlined),
      (AnimexPage.browse, 'Browse', Icons.explore_outlined),
      (AnimexPage.history, 'History', Icons.history_rounded),
    ];

    return Container(
      height: AnimeXTokens.headerHeight,
      decoration: BoxDecoration(
        color: AnimeXTokens.bg.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: AnimeXTokens.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AnimeXTokens.pageMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (isCoupleUser) ...[
                  AnimeXIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Dashboard',
                    onTap: () => context.go('/dashboard'),
                  ),
                  const SizedBox(width: 4),
                ] else if (isCinemaOnlyUser) ...[
                  AnimeXIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Cinema',
                    onTap: () => context.go('/cinema'),
                  ),
                  const SizedBox(width: 4),
                ],
                _Logo(onTap: () => controller.goTo(AnimexPage.home)),
                if (isDesktop) ...[
                  const SizedBox(width: 8),
                  for (final (page, label, _) in items) ...[
                    _NavItem(
                      label: label,
                      active: controller.page == page && !controller.hasDetail,
                      onTap: () => controller.goTo(page),
                    ),
                  ],
                ],
                const Spacer(),
                if (isCinemaOnlyUser) ...[
                  AnimeXGhostButton(
                    label: 'Cinema',
                    icon: Icons.movie_outlined,
                    color: AnimeXTokens.textPrimary,
                    onTap: () => context.go('/cinema'),
                  ),
                  const SizedBox(width: 4),
                ],
                AnimeXIconButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  onTap: onSearch,
                ),
                const SizedBox(width: 4),
                AnimeXGhostButton(
                  label: 'My List',
                  icon: Icons.bookmark_add_outlined,
                  color: AnimeXTokens.textPrimary,
                  onTap: () => controller.goTo(AnimexPage.myList),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 8),
                  const _SourceToggle(),
                  const SizedBox(width: 8),
                  _TitleLanguageToggle(),
                  const SizedBox(width: 10),
                ],
                AnimeXLoginButton(
                  label: userName.isEmpty ? 'Login' : userName,
                  icon: Icons.person_outline_rounded,
                  onTap: () => controller.goTo(AnimexPage.myList),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation used on mobile, mirroring the reference app bar.
class AnimeXMobileBottomNav extends StatelessWidget {
  final AnimeXController controller;
  final VoidCallback onSearch;

  const AnimeXMobileBottomNav({
    super.key,
    required this.controller,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(AnimexPage, String, IconData, IconData)>[
      (AnimexPage.home, 'Home', Icons.home_outlined, Icons.home_rounded),
      (
        AnimexPage.browse,
        'Browse',
        Icons.compass_calibration_outlined,
        Icons.compass_calibration_rounded,
      ),
      (
        AnimexPage.schedule,
        'Schedule',
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
      ),
      (AnimexPage.search, 'Search', Icons.search_rounded, Icons.search_rounded),
      (
        AnimexPage.myList,
        'My List',
        Icons.bookmark_add_outlined,
        Icons.bookmark_add_rounded,
      ),
      (
        AnimexPage.history,
        'History',
        Icons.history_rounded,
        Icons.history_rounded,
      ),
    ];

    return Container(
      height: AnimeXTokens.mobileNavHeight,
      padding: const EdgeInsets.only(bottom: 0),
      decoration: const BoxDecoration(
        color: Color(0xFA0A0A0F),
        border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: [
          for (final (page, label, icon, activeIcon) in items)
            Expanded(
              child: _MobileItem(
                label: label,
                icon: controller.page == page ? activeIcon : icon,
                active: controller.page == page && !controller.hasDetail,
                onTap: page == AnimexPage.search
                    ? onSearch
                    : () => controller.goTo(page),
              ),
            ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final VoidCallback onTap;
  const _Logo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text.rich(
          TextSpan(
            text: 'EVER',
            style: bebasStyle(size: 26, color: AnimeXTokens.textPrimary),
            children: [
              TextSpan(
                text: 'GLOW',
                style: bebasStyle(size: 26, color: AnimeXTokens.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AnimeXTokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: dmSansStyle(
              size: 14,
              color: active
                  ? AnimeXTokens.textPrimary
                  : AnimeXTokens.textSecondary,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// MAL / AniList segmented pill (visual source switcher).
class _SourceToggle extends StatefulWidget {
  const _SourceToggle();

  @override
  State<_SourceToggle> createState() => _SourceToggleState();
}

class _SourceToggleState extends State<_SourceToggle> {
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    return _SegmentedPill(
      labels: const ['MAL', 'AniList'],
      selected: _index,
      activeBackground: const Color(0xFF3DB4F2),
      onSelect: (i) => setState(() => _index = i),
    );
  }
}

/// EN / JP title-language toggle wired to [AnimexStores].
class _TitleLanguageToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final japanese = context.select(
      (AnimexStores stores) => stores.titleJapanese,
    );
    return _SegmentedPill(
      labels: const ['EN', 'JP'],
      selected: japanese ? 1 : 0,
      activeBackground: AnimeXTokens.accent,
      onSelect: (i) => context.read<AnimexStores>().setTitleJapanese(i == 1),
    );
  }
}

class _SegmentedPill extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final Color activeBackground;
  final ValueChanged<int> onSelect;

  const _SegmentedPill({
    required this.labels,
    required this.selected,
    required this.activeBackground,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onSelect(i),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: i == selected
                        ? activeBackground
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: i == selected
                        ? [
                            BoxShadow(
                              color: activeBackground.withValues(alpha: 0.25),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: dmSansStyle(
                      size: 11,
                      color: i == selected
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MobileItem({
    required this.label,
    required this.icon,
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
            icon,
            size: 20,
            color: active ? AnimeXTokens.accent : AnimeXTokens.textMuted,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: dmSansStyle(
              size: 9.5,
              color: active ? AnimeXTokens.accent : AnimeXTokens.textMuted,
              weight: FontWeight.w600,
              letterSpacing: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}
