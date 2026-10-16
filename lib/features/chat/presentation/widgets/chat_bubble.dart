import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/text_utils.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

/// A quiet message bubble with selectable text and accessible message actions.
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String sender;
  final DateTime timestamp;
  final bool showSender;
  final bool isOptimistic;
  final bool isFailed;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.sender,
    required this.timestamp,
    this.showSender = true,
    this.isOptimistic = false,
    this.isFailed = false,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(timestamp);
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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.84),
          child: Semantics(
            label: isMe ? 'You at $timeStr' : '$sender at $timeStr',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe && showSender)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 7),
                      child: Text(
                        displayNameFor(sender),
                        style: AppTypography.bodySmall().copyWith(
                          color: AppColors.blushGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onLongPress: copy,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 5),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.roseDepths : AppColors.silk,
                        border: isFailed
                            ? Border.all(color: AppColors.error)
                            : null,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 5),
                          bottomRight: Radius.circular(isMe ? 5 : 20),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            text,
                            style: AppTypography.bodyMedium().copyWith(
                              color: AppColors.petalWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                timeStr,
                                style: AppTypography.bodySmall().copyWith(
                                  fontSize: 11,
                                  color: isMe
                                      ? AppColors.petalWhite.withValues(
                                          alpha: 0.8,
                                        )
                                      : AppColors.textMedium,
                                ),
                              ),
                              if (isOptimistic) ...[
                                const SizedBox(width: 6),
                                const Tooltip(
                                  message: 'Sending',
                                  child: Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: AppColors.roseQuartz,
                                  ),
                                ),
                              ],
                              PopupMenuButton<String>(
                                tooltip: 'Message actions',
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 18,
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                padding: EdgeInsets.zero,
                                onSelected: (_) => copy(),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'copy',
                                    child: Text('Copy message'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isFailed)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Not sent',
                          style: AppTypography.bodySmall().copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Retry'),
                        ),
                        if (onDismiss != null)
                          TextButton(
                            onPressed: onDismiss,
                            child: const Text('Delete'),
                          ),
                      ],
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
