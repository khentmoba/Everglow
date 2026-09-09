import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/hidden_note.dart';

/// A love-letter card for the Letterbox rail.
///
/// One envelope shape, three moods:
/// - sealed (locked): deep plum + gold wax seal, countdown pill
/// - unread: rose glow + NEW ribbon, inviting Clair to open it
/// - read: quiet resting state
class NoteCard extends StatefulWidget {
  final HiddenNote note;
  final VoidCallback onTap;

  const NoteCard({super.key, required this.note, required this.onTap});

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final unlocked = note.isUnlocked;
    final isNew = unlocked && !note.isRead;

    final Color hue;
    if (!unlocked) {
      hue = AppColors.blushGold;
    } else if (isNew) {
      hue = AppColors.auroraRose;
    } else {
      hue = AppColors.softLavender;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: Semantics(
            button: true,
            label:
                '${note.title}, ${!unlocked ? 'sealed' : isNew ? 'new, waiting to be read' : 'read'}',
            child: AnimatedContainer(
              duration: AppMotion.orZero(AppMotion.fast),
              curve: AppMotion.easeOutStrong,
              width: 156,
              height: 188,
              transform: Matrix4.identity()
                ..translateByDouble(0, _hovered && !_pressed ? -4 : 0, 0, 1)
                ..scaleByDouble(
                  _pressed ? 0.96 : (_hovered ? 1.02 : 1.0),
                  _pressed ? 0.96 : (_hovered ? 1.02 : 1.0),
                  _pressed ? 0.96 : (_hovered ? 1.02 : 1.0),
                  1.0,
                ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    hue.withValues(alpha: isNew ? 0.22 : 0.14),
                    AppColors.velvet.withValues(alpha: 0.92),
                    AppColors.inkDeep.withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: _hovered
                      ? hue.withValues(alpha: 0.6)
                      : isNew
                          ? hue.withValues(alpha: 0.45)
                          : hue.withValues(alpha: 0.24),
                  width: isNew ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.inkDeep.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: hue.withValues(
                      alpha: isNew ? 0.28 : (_hovered ? 0.2 : 0.1),
                    ),
                    blurRadius: isNew ? 22 : 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    // Envelope sheen across the top.
                    Positioned(
                      top: 0,
                      left: 24,
                      right: 24,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              hue.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Faint envelope watermark.
                    Positioned(
                      right: -12,
                      bottom: -12,
                      child: IgnorePointer(
                        child: Icon(
                          Icons.mail_outline_rounded,
                          size: 88,
                          color: AppColors.petalWhite.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    if (isNew)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.auroraRose,
                                AppColors.deepRose,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.auroraRose.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            'NEW',
                            style: AppTypography.outfitHeading.copyWith(
                              fontSize: 8,
                              letterSpacing: 1.2,
                              color: AppColors.petalWhite,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SealMedallion(
                            hue: hue,
                            isNew: isNew,
                            unlocked: unlocked,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            note.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cormorantBold.copyWith(
                              fontSize: 16,
                              height: 1.15,
                              color: AppColors.petalWhite,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _StatePill(note: note, hue: hue, isNew: isNew),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wax-seal medallion: gold lock while sealed, glowing heart when new,
/// quiet envelope once read.
class _SealMedallion extends StatelessWidget {
  final Color hue;
  final bool isNew;
  final bool unlocked;

  const _SealMedallion({
    required this.hue,
    required this.isNew,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    if (!unlocked) {
      icon = Icons.lock_outline_rounded;
    } else if (isNew) {
      icon = Icons.favorite_rounded;
    } else {
      icon = Icons.drafts_outlined;
    }
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hue.withValues(alpha: isNew ? 0.4 : 0.28),
            hue.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: hue.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: isNew ? 0.35 : 0.18),
            blurRadius: isNew ? 18 : 12,
          ),
          BoxShadow(
            color: AppColors.petalWhite.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.petalWhite.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(child: Icon(icon, size: 24, color: hue)),
        ],
      ),
    );
  }
}

/// Bottom pill: countdown while sealed, invite when new, rest when read.
class _StatePill extends StatelessWidget {
  final HiddenNote note;
  final Color hue;
  final bool isNew;

  const _StatePill({
    required this.note,
    required this.hue,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData icon;
    if (!note.isUnlocked) {
      label = _countdownText(note.unlockDate);
      icon = Icons.hourglass_bottom_rounded;
    } else if (isNew) {
      label = 'tap to read';
      icon = Icons.touch_app_rounded;
    } else {
      label = 'read';
      icon = Icons.check_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: isNew ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: hue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: hue),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.3,
                color: hue.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _countdownText(DateTime unlockDate) {
    final diff = unlockDate.difference(DateTime.now());
    if (diff.inDays > 0) {
      return 'opens in ${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return 'opens in ${diff.inHours}h';
    } else {
      return 'opens soon';
    }
  }
}
