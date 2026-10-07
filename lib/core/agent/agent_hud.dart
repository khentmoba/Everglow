import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'agent_mode.dart';

/// Mounts the floating [AgentHud] across the app when Agent Mode is active.
///
/// Designed for local dev and agent verification sessions:
/// - Provides 1-click jumps across all major features.
/// - Allows switching profiles (Khent / Clair / Cinema guest).
/// - Can be collapsed into a tiny corner badge for clean PR screenshot capture.
class AgentHudOverlay extends StatelessWidget {
  final Widget child;

  const AgentHudOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AgentMode.isActive,
      builder: (context, active, _) {
        if (!active || !(AgentMode.isLocalDev || AgentMode.isCompiledIn)) {
          return child;
        }
        return ValueListenableBuilder<bool>(
          valueListenable: AgentMode.showHud,
          builder: (context, showHud, _) {
            if (!showHud) return child;
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Material(color: Colors.transparent, child: AgentHud()),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AgentHud extends StatefulWidget {
  const AgentHud({super.key});

  @override
  State<AgentHud> createState() => _AgentHudState();
}

class _AgentHudState extends State<AgentHud> {
  static const List<({String label, String route, IconData icon})> _routes = [
    (label: 'Dashboard', route: '/dashboard', icon: Icons.home_rounded),
    (label: 'Cinema', route: '/cinema', icon: Icons.movie_rounded),
    (label: 'Anime', route: '/anime', icon: Icons.smart_display_rounded),
    (label: 'Mangacelestia', route: '/manga', icon: Icons.auto_stories_rounded),
    (label: 'Books', route: '/books', icon: Icons.menu_book_rounded),
    (label: 'Sanctuary', route: '/sanctuary', icon: Icons.chat_bubble_rounded),
    (label: 'Gallery', route: '/gallery', icon: Icons.photo_library_rounded),
    (label: 'Journal', route: '/journal', icon: Icons.book_rounded),
    (label: 'Tonight', route: '/tonight', icon: Icons.nightlife_rounded),
    (label: 'Play Zone', route: '/play-zone', icon: Icons.sports_esports_rounded),
    (label: 'Academy', route: '/academy', icon: Icons.school_rounded),
    (label: 'Garden', route: '/garden', icon: Icons.local_florist_rounded),
    (label: 'Starlight', route: '/starlight', icon: Icons.star_rounded),
    (label: 'Calendar', route: '/calendar', icon: Icons.calendar_month_rounded),
    (label: 'Trip Kit', route: '/trip-kit', icon: Icons.flight_takeoff_rounded),
    (label: 'Canvas', route: '/canvas', icon: Icons.palette_rounded),
    (label: 'Bucket List', route: '/bucket-list', icon: Icons.checklist_rounded),
    (label: 'Money', route: '/money', icon: Icons.account_balance_wallet_rounded),
    (label: 'Jukebox', route: '/jukebox', icon: Icons.music_note_rounded),
    (label: 'Doorway', route: '/', icon: Icons.meeting_room_rounded),
  ];

  void _cycleProfile(BuildContext context) {
    final current = AgentMode.activeProfile.value;
    final next = switch (current) {
      'khentsgdz' => 'clairjassen',
      'clairjassen' => 'breyan',
      _ => 'khentsgdz',
    };
    AgentMode.switchProfile(next);
    context.read<AuthService>().enableAgentSession(profile: next);
  }

  String _profileLabel(String profile) {
    return switch (profile) {
      'khentsgdz' => 'Khent (Couple)',
      'clairjassen' => 'Clair (Couple)',
      'breyan' => 'Cinema (Guest)',
      _ => profile,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AgentMode.hudCollapsed,
      builder: (context, collapsed, _) {
        if (collapsed) {
          return Align(
            alignment: Alignment.bottomRight,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => AgentMode.hudCollapsed.value = false,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.velvet.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.auroraGold.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.auroraGold,
                    size: 20,
                  ),
                ),
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 820),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.inkDeep.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.auroraGold.withValues(alpha: 0.45),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.auroraGold,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AGENT SANDBOX',
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                        color: AppColors.auroraGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ValueListenableBuilder<String>(
                      valueListenable: AgentMode.activeProfile,
                      builder: (context, profile, _) {
                        return InkWell(
                          onTap: () => _cycleProfile(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.velvet.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.blushGold.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _profileLabel(profile),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.petalWhite,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 13,
                                  color: AppColors.blushGold,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    // This HUD sits above the Navigator in MaterialApp.builder,
                    // so it has no Overlay ancestor for a Tooltip.
                    Semantics(
                      button: true,
                      label: 'Collapse HUD (clean screenshot mode)',
                      child: InkWell(
                        onTap: () => AgentMode.hudCollapsed.value = true,
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.blushGold,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final item in _routes) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => context.go(item.route),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.velvet.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.moonlight.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 13,
                                    color: AppColors.petalWhite.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.petalWhite.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
