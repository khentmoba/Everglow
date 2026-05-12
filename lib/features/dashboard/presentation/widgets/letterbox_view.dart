import 'package:flutter/material.dart';
import '../../domain/models/hidden_note.dart';
import '../../data/services/letterbox_service.dart';
import 'note_card.dart';
import 'note_dialog.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/daily_bloom/presentation/providers/garden_provider.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text('No peeking! 🤫', textAlign: TextAlign.center),
        content: Text(
          'This letter is still sealed. It will unlock on ${_formatDate(note.unlockDate)}.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Okay, I\'ll wait! 🌸'),
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
            content: const Text('Letterbox reset successfully! 🌸'),
            backgroundColor: Colors.pink[300],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add notes: $e'),
            backgroundColor: Colors.red[300],
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[900],
                ),
              ),
              IconButton(
                onPressed: () => _seedSampleNotes(),
                icon: Icon(Icons.refresh, color: Colors.pink[200], size: 20),
                tooltip: 'Reset Seeds',
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: StreamBuilder<List<HiddenNote>>(
            stream: _letterboxService.notes,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.pinkAccent),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Oops! Something went wrong. 🌸',
                    style: TextStyle(color: Colors.pink[300]),
                  ),
                );
              }

              final notes = snapshot.data ?? [];

              if (notes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No letters yet... but keep checking back! 🌸',
                        style: TextStyle(
                          color: Colors.pink[300],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _seedSampleNotes(),
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Seed Sample Notes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink[100],
                          foregroundColor: Colors.pink[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
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
