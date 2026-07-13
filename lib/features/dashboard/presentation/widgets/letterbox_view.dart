import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/hidden_note.dart';
import '../../data/services/letterbox_service.dart';
import 'note_card.dart';
import 'note_dialog.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/daily_bloom/presentation/providers/garden_provider.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/shared/widgets/everglow/everglow_error_state.dart';
import 'package:everglow/shared/widgets/everglow/everglow_empty_state.dart';
import 'package:everglow/shared/widgets/everglow/everglow_skeleton.dart';
import 'package:google_fonts/google_fonts.dart';

class LetterboxView extends StatefulWidget {
  const LetterboxView({super.key});

  @override
  State<LetterboxView> createState() => _LetterboxViewState();
}

class _LetterboxViewState extends State<LetterboxView> {
  final LetterboxService _letterboxService = LetterboxService();

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
          'No peeking! 🤫',
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.roseQuartz,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        content: Text(
          'This letter is still sealed. It will unlock on ${_formatDate(note.unlockDate)}.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Okay, I\'ll wait! 🌸',
              style: GoogleFonts.outfit(
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
    // Persist read state to Firestore
    if (!note.isRead) {
      _letterboxService.markAsRead(note.id);
      // Increment garden interactions
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
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _seedSampleNotes() async {
    try {
      await _letterboxService.seedInitialNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Letterbox reset successfully! 🌸',
              style: GoogleFonts.outfit(color: AppTheme.petalWhite),
            ),
            backgroundColor: AppTheme.deepRose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add notes: $e',
              style: GoogleFonts.outfit(color: AppTheme.petalWhite),
            ),
            backgroundColor: Colors.red[900],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
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
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.roseQuartz,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => context.push('/letterbox'),
                    child: Text(
                      'View All',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.blushGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _seedSampleNotes(),
                    icon: const Icon(Icons.refresh, color: AppTheme.blushGold, size: 20),
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
            stream: _letterboxService.notes,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return EverglowErrorState(
                  message: 'Could not load letters',
                  onRetry: () => setState(() {}),
                  icon: Icons.cloud_off_rounded,
                );
              }

              if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: EverglowSkeleton(
                    width: 120,
                    height: 160,
                    radius: 16,
                  ),
                );
              }

              final notes = snapshot.data ?? [];

              if (notes.isEmpty) {
                return EverglowEmptyState(
                  icon: Icons.mail_outline_rounded,
                  title: 'No letters yet',
                  subtitle: 'Keep checking back! 🌸',
                  ctaLabel: 'Seed Sample Notes',
                  onCta: () => _seedSampleNotes(),
                );
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
