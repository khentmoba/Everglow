import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import 'everglow_markdown.dart';

/// Global chat bubble system — ONE look for Mochi, Study, and Sanctuary.
///
/// Why this exists: Mochi and Study each grew their own bubble containers,
/// so a visual fix in one never reached the other (the "still bad UI"
/// Khent flagged). Every assistant surface now builds on these two
/// widgets, so an upgrade here upgrades the whole app at once.
///
/// - [EverglowUserBubble] — warm rose gradient, right-aligned.
/// - [EverglowAssistantBubble] — frosted glass with Mochi header row,
///   markdown body, copy button, and timestamp footer.
/// - Both use Dusk Petal tokens only and stay selectable on web.
class EverglowUserBubble extends StatelessWidget {
  final String text;
  final String? timeLabel;
  final double maxWidthFactor;

  const EverglowUserBubble({
    super.key,
    required this.text,
    this.timeLabel,
    this.maxWidthFactor = 0.78,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: GestureDetector(
            onLongPress: () => copyText(context, text),
            child: Container(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.sizeOf(context).width * maxWidthFactor,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.deepRose,
                    AppColors.roseDepths,
                    AppColors.roseDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(6),
                ),
                border: Border.all(
                  color: AppColors.petalWhite.withValues(alpha: 0.20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.32),
                    blurRadius: 20,
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
                      color: AppColors.petalWhite,
                      height: 1.55,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (timeLabel != null && timeLabel!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 9,
                          color: AppColors.petalWhite.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeLabel!,
                          style: AppTypography.bodySmall().copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.petalWhite.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Assistant bubble shared by Mochi chat and Study answers.
///
/// [title] is "Mochi" in chat, "MOCHI" in Study; [subtitle] is the
/// context hint ("from your PDFs", "private memory + Everglow context").
/// Streaming callers pass [isStreaming] + [streamingFooter] to show the
/// caret / progress bar instead of the timestamp row.
class EverglowAssistantBubble extends StatelessWidget {
  final String text;
  final String title;
  final String? subtitle;
  final String? timeLabel;
  final bool isStreaming;
  final Widget? streamingFooter;
  final Widget? leadingReasoning;
  final String? avatarAsset;
  final double? maxWidth;

  const EverglowAssistantBubble({
    super.key,
    required this.text,
    this.title = 'Mochi',
    this.subtitle,
    this.timeLabel,
    this.isStreaming = false,
    this.streamingFooter,
    this.leadingReasoning,
    this.avatarAsset = 'assets/images/mochi_avatar.png',
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleMax = maxWidth ?? MediaQuery.sizeOf(context).width * 0.82;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avatarAsset != null)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blushGold.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                avatarAsset!,
                width: 36,
                height: 36,
                cacheWidth: kIsWeb ? null : 108,
                cacheHeight: kIsWeb ? null : 108,
                filterQuality: FilterQuality.high,
                fit: BoxFit.cover,
              ),
            ),
          ),
        if (avatarAsset != null) const SizedBox(width: 10),
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: bubbleMax),
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.velvet.withValues(alpha: 0.68),
                  AppColors.inkDeep.withValues(alpha: 0.88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppColors.auroraLilac.withValues(alpha: 0.09),
                  blurRadius: 24,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: MOCHI · context + copy.
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                      horizontal: 8.5,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blushGold.withValues(alpha: 0.12),
                      borderRadius: AppRadius.radiusFull,
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.28),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🐾', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 4.5),
                        Text(
                          title.toUpperCase(),
                          style: AppTypography.labelSmall().copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.blushGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '· $subtitle',
                        style: AppTypography.bodySmall().copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.roseQuartz.withValues(alpha: 0.82),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  EverglowCopyIconButton(textToCopy: text),
                ],
              ),
                const SizedBox(height: 9),
                if (leadingReasoning != null) ...[
                  leadingReasoning!,
                  const SizedBox(height: 8),
                ],
                if (isStreaming && text.trimLeft().isEmpty)
                  streamingFooter ?? const SizedBox.shrink()
                else
                  EverglowMarkdown(
                    text: text.trimLeft(),
                    baseStyle: AppTypography.bodyMedium().copyWith(
                      color: AppColors.textHigh,
                      height: 1.6,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (isStreaming && text.trimLeft().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  streamingFooter ?? const SizedBox.shrink(),
                ],
                if (!isStreaming && timeLabel != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 11,
                        color: AppColors.blushGold.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          timeLabel!,
                          style: AppTypography.bodySmall().copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Small copy icon used in every assistant bubble header.
class EverglowCopyIconButton extends StatelessWidget {
  final String textToCopy;
  const EverglowCopyIconButton({super.key, required this.textToCopy});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => copyText(context, textToCopy),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(
          Icons.copy_rounded,
          size: 14,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Shared copy + toast so every surface feels identical.
void copyText(BuildContext context, String text) {
  HapticFeedback.selectionClick();
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Copied', style: AppTypography.bodySmall()),
      duration: const Duration(seconds: 1),
      backgroundColor: AppColors.velvet,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
      margin: const EdgeInsets.all(16),
    ),
  );
}
