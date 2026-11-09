import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/system/tv_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/logger.dart';

/// Top media navigation bar optimized for TV remotes and guest profiles.
///
/// Gives 1-click / D-pad remote access between Everglow's three primary media sections:
/// Cinema 🎬, Anime 🌸, and MangaCelestia 📖.
class TvMediaNavHeader extends StatelessWidget {
  final String currentRoute;
  final VoidCallback? onLogout;

  const TvMediaNavHeader({
    super.key,
    required this.currentRoute,
    this.onLogout,
  });

  static const List<({String route, String label, IconData icon, Color accent})>
      mediaSections = [
    (
      route: '/cinema',
      label: 'Cinema',
      icon: Icons.movie_rounded,
      accent: AppColors.auroraGold,
    ),
    (
      route: '/anime',
      label: 'Anime',
      icon: Icons.animation_rounded,
      accent: AppColors.auroraRose,
    ),
    (
      route: '/manga',
      label: 'MangaCelestia',
      icon: Icons.auto_stories_rounded,
      accent: AppColors.roseQuartz,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isCouple = context.select<AuthService, bool>((a) => a.isCoupleUser);

    return ValueListenableBuilder<bool>(
      valueListenable: TvMode.isTvMode,
      builder: (context, isTv, _) {
        // Shown when TV mode is active.
        if (!isTv) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inkDeep.withValues(alpha: 0.94),
            border: Border(
              bottom: BorderSide(
                color: AppColors.moonlight.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.scrimStrong,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (isCouple)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _TvNavButton(
                              label: 'Dashboard',
                              icon: Icons.home_rounded,
                              accent: AppColors.auroraGold,
                              isSelected: false,
                              onPressed: () => context.go('/dashboard'),
                            ),
                          )
                        else
                          const SizedBox(width: 4),
                        // Section switch tabs
                        FocusTraversalGroup(
                          policy: ReadingOrderTraversalPolicy(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final sec in mediaSections) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: _TvNavButton(
                                    label: sec.label,
                                    icon: sec.icon,
                                    accent: sec.accent,
                                    isSelected: currentRoute == sec.route ||
                                        currentRoute.startsWith('${sec.route}/'),
                                    onPressed: () {
                                      if (currentRoute != sec.route) {
                                        context.go(sec.route);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // TV Mode toggle chip and Exit
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TvModeChip(isTv: isTv),
                            const SizedBox(width: 8),
                            _TvNavButton(
                              label: 'Exit',
                              icon: Icons.logout_rounded,
                              accent: AppColors.deepRose,
                              isSelected: false,
                              onPressed: () async {
                                if (onLogout != null) {
                                  onLogout!();
                                } else {
                                  final router = GoRouter.of(context);
                                  try {
                                    await context.read<AuthService>().logout();
                                  } catch (e, st) {
                                    Logger.e('TV logout failed', error: e, stackTrace: st);
                                  }
                                  router.go('/');
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TvNavButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool isSelected;
  final VoidCallback onPressed;

  const _TvNavButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  State<_TvNavButton> createState() => _TvNavButtonState();
}

class _TvNavButtonState extends State<_TvNavButton> {
  bool _focused = false;
  bool _hovered = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'tv-nav-${widget.label}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showHighlight = _focused || _hovered;

    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.isSelected,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && TvMode.isSelectKey(event.logicalKey)) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: AppMotion.orZero(AppMotion.fast),
              curve: AppMotion.easeOutStrong,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              transform: Matrix4.identity()
                ..scaleByDouble(
                  _focused ? 1.08 : (_hovered ? 1.03 : 1.0),
                  _focused ? 1.08 : (_hovered ? 1.03 : 1.0),
                  _focused ? 1.08 : (_hovered ? 1.03 : 1.0),
                  1.0,
                ),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.accent.withValues(alpha: 0.28)
                    : (showHighlight
                        ? AppColors.moonlight.withValues(alpha: 0.14)
                        : AppColors.velvet.withValues(alpha: 0.65)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _focused
                      ? widget.accent
                      : (widget.isSelected
                          ? widget.accent.withValues(alpha: 0.85)
                          : AppColors.moonlight.withValues(
                              alpha: _hovered ? 0.40 : 0.18,
                            )),
                  width: 2.0,
                ),
                boxShadow: _focused
                    ? TvMode.focusShadows(accent: widget.accent)
                    : (widget.isSelected
                        ? [
                            BoxShadow(
                              color: widget.accent.withValues(alpha: 0.40),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : const []),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: widget.isSelected
                        ? AppColors.petalWhite
                        : (_focused ? widget.accent : AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 14,
                      fontWeight:
                          widget.isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: widget.isSelected || _focused
                          ? AppColors.petalWhite
                          : AppColors.textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvModeChip extends StatelessWidget {
  final bool isTv;

  const _TvModeChip({required this.isTv});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isTv ? 'TV Mode Active (Click to toggle)' : 'Switch to TV Mode',
      child: InkWell(
        onTap: () => TvMode.toggle(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isTv
                ? AppColors.auroraGold.withValues(alpha: 0.20)
                : AppColors.velvet.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isTv
                  ? AppColors.auroraGold.withValues(alpha: 0.65)
                  : AppColors.moonlight.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tv_rounded,
                size: 15,
                color: isTv ? AppColors.auroraGold : AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                'TV',
                style: AppTypography.outfitMuted.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isTv ? AppColors.auroraGold : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
