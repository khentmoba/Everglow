import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../domain/models/star_note.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_typography.dart';

class NoteDisplayDialog extends StatefulWidget {
  final StarNote note;
  final bool showConfetti;

  const NoteDisplayDialog({
    super.key,
    required this.note,
    this.showConfetti = false,
  });

  @override
  State<NoteDisplayDialog> createState() => _NoteDisplayDialogState();
}

class _NoteDisplayDialogState extends State<NoteDisplayDialog>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );
    _scaleController.forward();

    if (widget.showConfetti) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = starCategoryInfo[widget.note.category] ??
        ('⭐', widget.note.category);

    return RepaintBoundary(
      child: Stack(
      children: [
        // Confetti overlay
        if (widget.showConfetti)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppTheme.blushGold,
                AppTheme.roseQuartz,
                AppTheme.softLavender,
                Colors.white,
                Color(0xFFFFF176),
              ],
              emissionFrequency: 0.08,
              numberOfParticles: 15,
            ),
          ),

        // Note dialog
        Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.velvet,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.blushGold.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.deepRose.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${info.$1} ${info.$2}",
                      style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppTheme.blushGold, letterSpacing: 0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.auto_awesome,
                    color: AppTheme.blushGold,
                    size: 36,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.note.content,
                    textAlign: TextAlign.center,
                    style: AppTypography.cormorantHeading.copyWith(fontSize: 22, color: AppTheme.roseQuartz, fontStyle: FontStyle.italic),
                  ),

                  // Tags
                  if (widget.note.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: widget.note.tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.softLavender.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "#$tag",
                                style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.softLavender),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Text(
                    "— ${widget.note.author.toUpperCase()}",
                    style: AppTypography.outfitWhite.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.blushGold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${widget.note.timestamp.month}/${widget.note.timestamp.day}/${widget.note.timestamp.year}",
                    style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppTheme.petalWhite.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepRose,
                      foregroundColor: AppTheme.petalWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      "Close",
                      style: AppTypography.outfitWhite.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
