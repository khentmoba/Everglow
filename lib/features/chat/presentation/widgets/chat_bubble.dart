import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/core/theme/app_radius.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String sender;
  final DateTime timestamp;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.sender,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(timestamp);
    final dateStr = DateFormat('MMM d').format(timestamp);
    final isToday = DateTime.now().day == timestamp.day &&
        DateTime.now().month == timestamp.month &&
        DateTime.now().year == timestamp.year;

    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  sender.toUpperCase(),
                  style: AppTypography.labelSmall().copyWith(
                    color: AppColors.blushGold,
                    letterSpacing: 1.2,
                    fontSize: 10,
                  ),
                ),
              ),
            GestureDetector(
              onLongPress: () {
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
                        borderRadius: AppRadius.radiusLg),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [
                            AppColors.deepRose
                                .withValues(alpha: 0.65),
                            AppColors.deepRose
                                .withValues(alpha: 0.35),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : AppColors.surfaceGlass,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(24),
                    topRight: const Radius.circular(24),
                    bottomLeft: Radius.circular(isMe ? 24 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 24),
                  ),
                  border: isMe
                      ? null
                      : Border.all(
                          color: AppColors.border, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: (isMe
                              ? AppColors.deepRose
                              : AppColors.roseQuartz)
                          .withValues(alpha: 0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      text,
                      style: AppTypography.bodyMedium().copyWith(
                        color: AppColors.petalWhite,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isToday ? timeStr : '$dateStr, $timeStr',
                      style: AppTypography.bodySmall().copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: isMe
                            ? AppColors.petalWhite
                                .withValues(alpha: 0.7)
                            : AppColors.roseQuartz
                                .withValues(alpha: 0.7),
                      ),
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
