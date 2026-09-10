import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import 'katana_theme.dart';

enum ReaderMode {
  webtoon,
  pagedRTL,
  pagedLTR;

  String get label {
    switch (this) {
      case ReaderMode.webtoon:
        return 'Webtoon (Vertical)';
      case ReaderMode.pagedRTL:
        return 'Manga (Right to Left)';
      case ReaderMode.pagedLTR:
        return 'Western (Left to Right)';
    }
  }

  IconData get icon {
    switch (this) {
      case ReaderMode.webtoon:
        return Icons.swap_vert_rounded;
      case ReaderMode.pagedRTL:
        return Icons.keyboard_double_arrow_left_rounded;
      case ReaderMode.pagedLTR:
        return Icons.keyboard_double_arrow_right_rounded;
    }
  }
}

enum ReaderThemeStyle {
  oled,
  plum,
  sepia;

  String get label {
    switch (this) {
      case ReaderThemeStyle.oled:
        return 'OLED Black';
      case ReaderThemeStyle.plum:
        return 'Plum Night';
      case ReaderThemeStyle.sepia:
        return 'Warm Sepia';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ReaderThemeStyle.oled:
        return const Color(0xFF000000);
      case ReaderThemeStyle.plum:
        return KatanaColors.background;
      case ReaderThemeStyle.sepia:
        return const Color(0xFF1E1A17);
    }
  }

  Color get surfaceColor {
    switch (this) {
      case ReaderThemeStyle.oled:
        return const Color(0xFF121212);
      case ReaderThemeStyle.plum:
        return KatanaColors.surface;
      case ReaderThemeStyle.sepia:
        return const Color(0xFF28231F);
    }
  }
}

class ReaderSettingsSheet extends StatelessWidget {
  final ReaderMode currentMode;
  final ReaderThemeStyle currentTheme;
  final double brightness;
  final bool twoPage;
  final String currentServer;
  final ValueChanged<ReaderMode> onModeChanged;
  final ValueChanged<ReaderThemeStyle> onThemeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<bool> onTwoPageChanged;
  final ValueChanged<String> onServerChanged;

  const ReaderSettingsSheet({
    super.key,
    required this.currentMode,
    required this.currentTheme,
    required this.brightness,
    required this.twoPage,
    required this.currentServer,
    required this.onModeChanged,
    required this.onThemeChanged,
    required this.onBrightnessChanged,
    required this.onTwoPageChanged,
    required this.onServerChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required ReaderMode currentMode,
    required ReaderThemeStyle currentTheme,
    required double brightness,
    required bool twoPage,
    required String currentServer,
    required ValueChanged<ReaderMode> onModeChanged,
    required ValueChanged<ReaderThemeStyle> onThemeChanged,
    required ValueChanged<double> onBrightnessChanged,
    required ValueChanged<bool> onTwoPageChanged,
    required ValueChanged<String> onServerChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: currentTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return ReaderSettingsSheet(
            currentMode: currentMode,
            currentTheme: currentTheme,
            brightness: brightness,
            twoPage: twoPage,
            currentServer: currentServer,
            onModeChanged: (mode) {
              setModalState(() {});
              onModeChanged(mode);
            },
            onThemeChanged: (theme) {
              setModalState(() {});
              onThemeChanged(theme);
            },
            onBrightnessChanged: (b) {
              setModalState(() {});
              onBrightnessChanged(b);
            },
            onTwoPageChanged: (tp) {
              setModalState(() {});
              onTwoPageChanged(tp);
            },
            onServerChanged: (srv) {
              setModalState(() {});
              onServerChanged(srv);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final canTwoPage = width >= 840;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KatanaColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: KatanaColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reader Settings',
                    style: AppTypography.outfitBold.copyWith(
                      color: KatanaColors.text,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Reading Mode
              Text(
                'READING MODE',
                style: AppTypography.outfitBold.copyWith(
                  color: KatanaColors.textLight,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final mode in ReaderMode.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: mode != ReaderMode.values.last ? 8.0 : 0.0,
                        ),
                        child: _OptionChip(
                          icon: mode.icon,
                          label: mode == ReaderMode.webtoon
                              ? 'Webtoon'
                              : mode == ReaderMode.pagedRTL
                                  ? 'Manga (RTL)'
                                  : 'Paged (LTR)',
                          isSelected: currentMode == mode,
                          onTap: () => onModeChanged(mode),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),

              // Background Theme
              Text(
                'BACKGROUND THEME',
                style: AppTypography.outfitBold.copyWith(
                  color: KatanaColors.textLight,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final theme in ReaderThemeStyle.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: theme != ReaderThemeStyle.values.last ? 8.0 : 0.0,
                        ),
                        child: _ThemeChip(
                          theme: theme,
                          isSelected: currentTheme == theme,
                          onTap: () => onThemeChanged(theme),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),

              // Night Dimmer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'NIGHT DIMMER',
                    style: AppTypography.outfitBold.copyWith(
                      color: KatanaColors.textLight,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${(brightness * 100).round()}%',
                    style: KatanaType.small.copyWith(
                      color: KatanaColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.brightness_low_rounded,
                    size: 18,
                    color: KatanaColors.textLight,
                  ),
                  Expanded(
                    child: Slider(
                      value: brightness,
                      min: 0.2,
                      max: 1.0,
                      divisions: 16,
                      activeColor: KatanaColors.accent,
                      inactiveColor: KatanaColors.border,
                      onChanged: onBrightnessChanged,
                    ),
                  ),
                  const Icon(
                    Icons.brightness_high_rounded,
                    size: 18,
                    color: KatanaColors.textLight,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tablet Two-Page Spread
              if (canTwoPage) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: KatanaColors.accent,
                  title: Text(
                    'Two-Page Spread (Tablet/Desktop)',
                    style: AppTypography.outfitBold.copyWith(
                      color: KatanaColors.text,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    'Shows two pages side by side in Paged mode',
                    style: KatanaType.small,
                  ),
                  value: twoPage,
                  onChanged: onTwoPageChanged,
                ),
                const SizedBox(height: 10),
              ],

              // Backup Image Servers
              Text(
                'BACKUP IMAGE SERVERS',
                style: AppTypography.outfitBold.copyWith(
                  color: KatanaColors.textLight,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'If pages are slow or failing, switch to a backup server.',
                style: KatanaType.small.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ServerPill(
                    label: 'Primary (Server 1)',
                    isSelected: currentServer == '',
                    onTap: () => onServerChanged(''),
                  ),
                  const SizedBox(width: 8),
                  _ServerPill(
                    label: 'Server 2',
                    isSelected: currentServer == '?sv=mk',
                    onTap: () => onServerChanged('?sv=mk'),
                  ),
                  const SizedBox(width: 8),
                  _ServerPill(
                    label: 'Server 3',
                    isSelected: currentServer == '?sv=3',
                    onTap: () => onServerChanged('?sv=3'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? KatanaColors.accent.withValues(alpha: 0.16)
              : KatanaColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? KatanaColors.accent : KatanaColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? KatanaColors.accent : KatanaColors.textLight,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitBold.copyWith(
                color: isSelected ? KatanaColors.accent : KatanaColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final ReaderThemeStyle theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? KatanaColors.accent : KatanaColors.border,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? KatanaColors.accent : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 12,
                      color: KatanaColors.accent,
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              theme.label,
              style: AppTypography.outfitBold.copyWith(
                color: isSelected ? KatanaColors.accent : KatanaColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServerPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? KatanaColors.accent.withValues(alpha: 0.16)
                : KatanaColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? KatanaColors.accent : KatanaColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.outfitBold.copyWith(
              color: isSelected ? KatanaColors.accent : KatanaColors.textLight,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}
