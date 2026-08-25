import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/hidden_note.dart';
import '../../data/services/letterbox_service.dart';
import 'note_card.dart';
import 'note_dialog.dart';
import 'package:provider/provider.dart';
import '../../../daily_bloom/presentation/providers/garden_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../core/theme/app_typography.dart';

class LetterboxView extends StatefulWidget {
  const LetterboxView({super.key});

  @override
  State<LetterboxView> createState() => _LetterboxViewState();
}

class _LetterboxViewState extends State<LetterboxView> {
  final LetterboxService _letterboxService = LetterboxService();
  int _streamVersion = 0;

  void _handleNoteTap(HiddenNote note) {
    if (!note.isUnlocked) {
      _showLockedAlert(note);
    } else {
      _openNote(note);
    }
  }

  void _showLockedAlert(HiddenNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppTheme.velvet,
        title: Text(
          'No peeking! \u{1F92B}',
          textAlign: TextAlign.center,
          style: AppTypography.cormorantBold.copyWith(fontSize: 24),
        ),
        content: Text(
          'This letter is still sealed. It will unlock on ${_formatDate(note.unlockDate)}.',
          textAlign: TextAlign.center,
          style: AppTypography.outfitWhite.copyWith(
            color: AppTheme.petalWhite.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Okay, I''ll wait! \u{1F338}',
              style: AppTypography.outfitWhite.copyWith(
                color: AppTheme.blushGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openNote(HiddenNote note) {
    if (!note.isRead) {
      _letterboxService.markAsRead(note.id);
      context.read<GardenProvider>().recordInteraction();
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Note',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return NoteDialog(note: note);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Future<void> _seedSampleNotes() async {
    try {
      await _letterboxService.seedInitialNotes();
      if (!mounted) return;
      // Force StreamBuilder to resubscribe with a fresh timeout stream.
      // Without this, a previous withFirestoreTimeout that already fired
      // would stay closed and never show the newly seeded note (the
      // "No letters yet" stuck bug).
      setState(() => _streamVersion++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Letterbox reset successfully! \u{1F338}',
            style: AppTypography.outfitWhite.copyWith(
              color: AppTheme.petalWhite,
            ),
          ),
          backgroundColor: AppTheme.deepRose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _streamVersion++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add notes: $e',
            style: AppTypography.outfitWhite.copyWith(
              color: AppTheme.petalWhite,
            ),
          ),
          backgroundColor: Colors.red[900],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Letterbox',
                style: AppTypography.cormorantBold.copyWith(fontSize: 24),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => context.push('/letterbox'),
                    child: Text(
                      'View All',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppTheme.blushGold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _seedSampleNotes,
                    icon: const Icon(
                      Icons.refresh,
                      color: AppTheme.blushGold,
                      size: 20,
                    ),
                    tooltip: 'Reset Seeds',
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: StreamBuilder<List<HiddenNote>>(
            // Bust cache when we seed or retry so a timed-out
            // withFirestoreTimeout stream is replaced.
            key: ValueKey(_streamVersion),
            stream: _letterboxService.notes,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _LetterboxError(
                  onRetry: () => setState(() => _streamVersion++),
                );
              }

              // Treat a closed stream with no data as a timeout error
              // (withFirestoreTimeout now emits TimeoutException, but keep
              // this fallback for any silent close).
              if (snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasData) {
                return _LetterboxError(
                  onRetry: () => setState(() => _streamVersion++),
                );
              }

              if (!snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: EverglowSkeleton(width: 120, height: 160, radius: 16),
                );
              }

              final notes = snapshot.data ?? [];

              if (notes.isEmpty) {
                return _LetterboxRailEmpty(onSeed: _seedSampleNotes);
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  return NoteCard(
                    note: notes[index],
                    onTap: () => _handleNoteTap(notes[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Compact empty rail that fits inside the 200px Letterbox carousel.
/// The previous EverglowEmptyState (96px medallion + CTA) overflowed the
/// 200px SizedBox and bled into the Jukebox card below (screenshot bug).
class _LetterboxRailEmpty extends StatelessWidget {
  final VoidCallback onSeed;
  const _LetterboxRailEmpty({required this.onSeed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          height: 172,
          decoration: BoxDecoration(
            color: AppColors.velvet.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.inkDeep.withValues(alpha: 0.9),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepRose.withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: 24,
                  color: AppColors.roseQuartz,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'No letters yet',
                style: AppTypography.cormorantBold.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep checking back! \u{1F338}',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 12,
                  color: AppColors.petalWhite.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onSeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.deepRose, AppColors.velvet],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'Seed Sample Notes',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 12,
                      color: AppColors.petalWhite,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LetterboxError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LetterboxError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: 172,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.velvet.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: AppColors.roseQuartz,
              ),
              const SizedBox(height: 8),
              Text(
                'Could not load letters',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 13,
                  color: AppColors.petalWhite,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Check connection and try again',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppColors.petalWhite.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.deepRose.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.deepRose.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: AppColors.petalWhite,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Retry',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 12,
                          color: AppColors.petalWhite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}