import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/study_artifact.dart';
import 'canvas_preview_sheet.dart';

part 'study_artifact_quiz.dart';
part 'study_artifact_flashcards.dart';

/// Study canvas — the Artifacts-style interactive layer for Study replies.
///
/// When Motchi's answer carries a quiz or flashcards, the bubble shows one
/// big obvious button ("Try the quiz ✍️" / "Flip the cards 🃏") instead of
/// raw text. Tapping opens this sheet:
///
/// - Phone / tablet (Clair's world): a near-full bottom sheet she can drag.
/// - Desktop: a centered dialog, same content.
///
/// One code path for both, so a fix here reaches every screen size.
enum StudyArtifactTab { quiz, flashcards }

/// Opens the interactive sheet. Picks tabs automatically when only one
/// artifact kind is present.
Future<void> openStudyArtifactSheet(
  BuildContext context,
  StudyArtifacts artifacts, {
  StudyArtifactTab? initialTab,
}) {
  final tab =
      initialTab ??
      (artifacts.hasQuiz ? StudyArtifactTab.quiz : StudyArtifactTab.flashcards);
  final sheet = StudyArtifactSheet(artifacts: artifacts, initialTab: tab);
  if (MediaQuery.sizeOf(context).width >= 1024) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: _SheetChrome(child: sheet),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, controller) =>
          _SheetChrome(scrollController: controller, child: sheet),
    ),
  );
}

/// The little launcher pill at the top of a Study answer bubble.
/// Renders nothing when the reply has no interactive content.
class StudyArtifactEntry extends StatelessWidget {
  final StudyArtifacts artifacts;

  const StudyArtifactEntry({super.key, required this.artifacts});

  @override
  Widget build(BuildContext context) {
    if (artifacts.isEmpty) return const SizedBox.shrink();
    final buttons = <Widget>[];
    if (artifacts.hasQuiz) {
      buttons.add(
        _LaunchButton(
          icon: Icons.edit_note_rounded,
          label:
              'Try the quiz ✍️ · ${artifacts.quiz.length} question${artifacts.quiz.length == 1 ? '' : 's'}',
          onTap: () => openStudyArtifactSheet(
            context,
            artifacts,
            initialTab: StudyArtifactTab.quiz,
          ),
        ),
      );
    }
    if (artifacts.hasFlashcards) {
      buttons.add(
        _LaunchButton(
          icon: Icons.style_rounded,
          label:
              'Flip the cards 🃏 · ${artifacts.flashcards.length} card${artifacts.flashcards.length == 1 ? '' : 's'}',
          onTap: () => openStudyArtifactSheet(
            context,
            artifacts,
            initialTab: StudyArtifactTab.flashcards,
          ),
        ),
      );
    }
    if (artifacts.hasHtml) {
      for (final app in artifacts.html) {
        buttons.add(
          _LaunchButton(
            icon: Icons.play_circle_fill_rounded,
            label: 'Preview 🔍 · ${app.title}',
            onTap: () => openCanvasPreview(context, app),
          ),
        );
      }
    }
    if (artifacts.hasLinks) {
      for (final link in artifacts.links) {
        buttons.add(
          _LaunchButton(
            icon: Icons.sports_esports_rounded,
            label: link.label,
            onTap: () => context.push(link.route),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
        ],
      ),
    );
  }
}

class _LaunchButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LaunchButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_LaunchButton> createState() => _LaunchButtonState();
}

class _LaunchButtonState extends State<_LaunchButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isGame = widget.label.contains('Preview') ||
        widget.icon == Icons.play_circle_fill_rounded ||
        widget.icon == Icons.sports_esports_rounded;
    final isQuiz = widget.label.contains('Try the quiz');
    final isCards = widget.label.contains('Flip the cards');

    final String tag;
    final String actionText;
    final List<Color> badgeGradient;
    final List<Color> actionGradient;
    final Color accentColor;
    final IconData mainIcon;

    if (isGame) {
      tag = '🐾 MINI GAME · PLAY TOGETHER';
      actionText = 'Play';
      badgeGradient = const [AppColors.auroraRose, AppColors.auroraGold];
      actionGradient = const [AppColors.deepRose, AppColors.auroraRose];
      accentColor = AppColors.auroraRose;
      mainIcon = Icons.sports_esports_rounded;
    } else if (isQuiz) {
      tag = '🐾 MOTCHI QUIZ · TEST YOUR KNOWLEDGE';
      actionText = 'Quiz';
      badgeGradient = const [AppColors.blushGold, AppColors.warmAmber];
      actionGradient = const [AppColors.blushGold, AppColors.deepRose];
      accentColor = AppColors.blushGold;
      mainIcon = Icons.quiz_rounded;
    } else if (isCards) {
      tag = '🐾 FLASHCARDS · STUDY TOGETHER';
      actionText = 'Cards';
      badgeGradient = const [AppColors.auroraLilac, AppColors.softLavender];
      actionGradient = const [AppColors.auroraLilac, AppColors.plum];
      accentColor = AppColors.auroraLilac;
      mainIcon = Icons.style_rounded;
    } else {
      tag = '🐾 INTERACTIVE ARTIFACT';
      actionText = 'Open';
      badgeGradient = const [AppColors.blushGold, AppColors.deepRose];
      actionGradient = const [AppColors.deepRose, AppColors.roseDepths];
      accentColor = AppColors.blushGold;
      mainIcon = widget.icon;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _hover
                      ? AppColors.inkDeep.withValues(alpha: 0.95)
                      : AppColors.inkDeep.withValues(alpha: 0.88),
                  _hover
                      ? AppColors.velvet.withValues(alpha: 0.82)
                      : AppColors.velvet.withValues(alpha: 0.70),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hover
                    ? accentColor.withValues(alpha: 0.45)
                    : accentColor.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
                if (_hover)
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Glowing icon token badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: badgeGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: badgeGradient.first.withValues(alpha: 0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    mainIcon,
                    size: 20,
                    color: AppColors.petalWhite,
                  ),
                ),
                const SizedBox(width: 12),
                // Tag & Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag,
                        style: AppTypography.labelSmall().copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: accentColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.label,
                        style: AppTypography.bodyMedium().copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.petalWhite,
                          height: 1.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Action pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: actionGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadius.radiusFull,
                    boxShadow: [
                      BoxShadow(
                        color: actionGradient.first.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionText,
                        style: AppTypography.bodySmall().copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.petalWhite,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: AppColors.petalWhite,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetChrome extends StatelessWidget {
  final Widget child;
  final ScrollController? scrollController;

  const _SheetChrome({required this.child, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.velvet.withValues(alpha: 0.98),
            AppColors.inkDeep.withValues(alpha: 0.99),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
          bottom: Radius.circular(24),
        ),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
          BoxShadow(
            color: AppColors.blushGold.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (scrollController != null) ...[
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.35),
                  borderRadius: AppRadius.radiusFull,
                ),
              ),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class StudyArtifactSheet extends StatefulWidget {
  final StudyArtifacts artifacts;
  final StudyArtifactTab initialTab;

  const StudyArtifactSheet({
    super.key,
    required this.artifacts,
    required this.initialTab,
  });

  @override
  State<StudyArtifactSheet> createState() => _StudyArtifactSheetState();
}

class _StudyArtifactSheetState extends State<StudyArtifactSheet> {
  late StudyArtifactTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final showTabs = widget.artifacts.hasQuiz && widget.artifacts.hasFlashcards;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🐾 MOTCHI STUDY',
                      style: AppTypography.labelSmall().copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.blushGold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tab == StudyArtifactTab.quiz
                          ? 'Quiz time ✍️'
                          : 'Flashcards 🃏',
                      style: AppTypography.titleLarge().copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: 'Back to chat',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 19),
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (showTabs)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: _TabSwitch(
              tab: _tab,
              quizCount: widget.artifacts.quiz.length,
              cardCount: widget.artifacts.flashcards.length,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
        Flexible(
          child: _tab == StudyArtifactTab.quiz
              ? QuizPlayView(questions: widget.artifacts.quiz)
              : FlashcardsPlayView(cards: widget.artifacts.flashcards),
        ),
      ],
    );
  }
}

class _TabSwitch extends StatelessWidget {
  final StudyArtifactTab tab;
  final int quizCount;
  final int cardCount;
  final ValueChanged<StudyArtifactTab> onChanged;

  const _TabSwitch({
    required this.tab,
    required this.quizCount,
    required this.cardCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.inkDeep.withValues(alpha: 0.9),
            AppColors.velvet.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          _tabOption(context, StudyArtifactTab.quiz, 'Quiz · $quizCount'),
          _tabOption(context, StudyArtifactTab.flashcards, 'Cards · $cardCount'),
        ],
      ),
    );
  }

  Widget _tabOption(
    BuildContext context,
    StudyArtifactTab value,
    String label,
  ) {
    final selected = tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [AppColors.blushGold, AppColors.deepRose],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: AppRadius.radiusFull,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.bodySmall().copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.petalWhite
                    : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

