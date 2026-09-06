import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

/// Sanctuary couple-chat bubble — same premium language as Mochi/Study.
///
/// - Mine: warm rose gradient, right-aligned, soft glow.
/// - Theirs: frosted glass with lilac glow, sender label with gold dot.
/// Long-press or the copy icon copies the message.
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String sender;
  final DateTime timestamp;
  final bool showSender;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.sender,
    required this.timestamp,
    this.showSender = true,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(timestamp);
    final dateStr = DateFormat('MMM d').format(timestamp);
    final now = DateTime.now();
    final isToday =
        now.day == timestamp.day &&
        now.month == timestamp.month &&
        now.year == timestamp.year;

    void copy() {
      HapticFeedback.selectionClick();
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied to clipboard',
            style: AppTypography.bodySmall(),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.velvet,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLg,
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    return Semantics(
      label: isMe ? 'You at $timeStr: $text' : '$sender at $timeStr: $text',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && showSender)
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.blushGold,
                            AppColors.deepRose,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.blushGold.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sender.toUpperCase(),
                      style: AppTypography.labelSmall().copyWith(
                        color: AppColors.blushGold,
                        letterSpacing: 1.2,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            GestureDetector(
              onLongPress: copy,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [
                            AppColors.deepRose,
                            AppColors.roseDepths,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            AppColors.moonlight.withValues(alpha: 0.13),
                            AppColors.moonlight.withValues(alpha: 0.07),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: isMe ? null : AppColors.panelGlass,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                      isMe ? AppRadius.x2 : AppRadius.xs,
                    ),
                    topRight: Radius.circular(
                      isMe ? AppRadius.xs : AppRadius.x2,
                    ),
                    bottomLeft: const Radius.circular(AppRadius.xl),
                    bottomRight: const Radius.circular(AppRadius.xl),
                  ),
                  border: Border.all(
                    color: isMe
                        ? AppColors.petalWhite.withValues(alpha: 0.14)
                        : AppColors.moonlight.withValues(alpha: 0.16),
                  ),
                  boxShadow: [
                    ...AppElevation.e2,
                    BoxShadow(
                      color: (isMe
                              ? AppColors.deepRose
                              : AppColors.auroraLilac)
                          .withValues(alpha: isMe ? 0.30 : 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      text,
                      style: AppTypography.bodyMedium().copyWith(
                        color: isMe
                            ? AppColors.petalWhite
                            : AppColors.textHigh,
                        height: 1.55,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isToday ? timeStr : '$dateStr, $timeStr',
                          style: AppTypography.bodySmall().copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isMe
                                ? AppColors.petalWhite
                                    .withValues(alpha: 0.65)
                                : AppColors.textMuted
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: copy,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 11,
                              color: isMe
                                  ? AppColors.petalWhite
                                      .withValues(alpha: 0.55)
                                  : AppColors.textDisabled
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
