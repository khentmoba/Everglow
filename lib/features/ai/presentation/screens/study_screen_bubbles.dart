part of 'study_screen.dart';

/// Small circular action used in the Study header (history / new study).
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusFull,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceGlass,
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Icon(icon, size: 18, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

/// User question — global rose bubble shared with Motchi chat.
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 12),
      child: EverglowUserBubble(text: text),
    );
  }
}

/// Motchi answer — the same global assistant bubble Motchi chat uses,
/// so a fix here upgrades both surfaces at once. When the reply carries
/// a quiz or flashcards, one big button opens the interactive canvas
/// (tappable answers, flippable cards); the hidden data block is stripped
/// so Clair never sees raw JSON.
class _AnswerBubble extends StatelessWidget {
  final String text;
  // Canvas toggle from the Study bar — when false the bubble stays plain
  // text (hidden blocks still stripped so raw JSON never shows).
  final bool showArtifacts;
  // When true the full visible question list is kept: the user explicitly
  // asked to see it inline (see userAskedForVisibleQuiz).
  final bool keepFullText;
  const _AnswerBubble({
    required this.text,
    this.showArtifacts = true,
    this.keepFullText = false,
  });

  @override
  Widget build(BuildContext context) {
    final artifacts = parseStudyArtifacts(text);
    final displayText = artifacts.isEmpty
        ? text
        : stripArtifactBlocks(text, collapseVisibleLists: !keepFullText);
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 12),
      child: EverglowAssistantBubble(
        text: displayText,
        title: 'Motchi',
        subtitle: 'from your PDFs',
        timeLabel: 'Motchi • grounded only on your pages',
        leadingReasoning: !showArtifacts || artifacts.isEmpty
            ? null
            : StudyArtifactEntry(artifacts: artifacts),
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble();

  @override
  Widget build(BuildContext context) {
    final ai = context.read<AIService>();
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                'assets/images/motchi_avatar.webp',
                width: 36,
                height: 36,
                cacheWidth: kIsWeb ? null : 108,
                cacheHeight: kIsWeb ? null : 108,
                filterQuality: FilterQuality.high,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
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
              child: ValueListenableBuilder<String>(
                valueListenable: ai.draftResponseNotifier,
                builder: (_, draft, _) {
                  draft = stripStreamingArtifacts(draft);
                  if (draft.isEmpty) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Motchi is reading',
                          style: AppTypography.bodyMedium().copyWith(
                            color: AppColors.textMuted,
                            height: 1.5,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.blushGold,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EverglowMarkdown(
                        text: draft,
                        baseStyle: AppTypography.bodyMedium().copyWith(
                          color: AppColors.textHigh,
                          height: 1.6,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: AppColors.moonlight.withValues(
                            alpha: 0.14,
                          ),
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.blushGold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
