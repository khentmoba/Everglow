import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/everglow/everglow_error_state.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../domain/models/hidden_note.dart';
import '../../data/services/letterbox_service.dart';
import '../widgets/note_dialog.dart';
import '../../../../core/theme/app_typography.dart';

/// Full-screen letter archive with search and filter (locked / unread / read).
class LetterboxArchiveScreen extends StatefulWidget {
  const LetterboxArchiveScreen({super.key});

  @override
  State<LetterboxArchiveScreen> createState() => _LetterboxArchiveScreenState();
}

enum _LetterFilter { all, locked, unread, read }

class _LetterArchiveSearchDelegate extends StatelessWidget {
  final List<HiddenNote> notes;
  final void Function(HiddenNote) onNoteTap;

  const _LetterArchiveSearchDelegate({
    required this.notes,
    required this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Search Letters', style: AppTypography.cormorantBold),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.roseQuartz,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: notes.isEmpty
          ? const EverglowEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No letters found',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                return _LetterListTile(
                  note: notes[index],
                  onTap: () => onNoteTap(notes[index]),
                );
              },
            ),
    );
  }
}

class _LetterboxArchiveScreenState extends State<LetterboxArchiveScreen> {
  final LetterboxService _service = LetterboxService();
  _LetterFilter _filter = _LetterFilter.all;
  final String _searchQuery = '';
  int _streamVersion = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.roseQuartz,
          ),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Letter Archive',
          style: AppTypography.cormorantBold.copyWith(fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.blushGold),
            onPressed: () => _openSearch(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraGold,
                  alignment: Alignment(-0.7, -0.9),
                  size: 0.9,
                  opacity: 0.10,
                ),
                RadialGlow(
                  color: AppColors.softLavender,
                  alignment: Alignment(0.9, 0.8),
                  size: 0.7,
                  opacity: 0.10,
                ),
              ],
              showPetals: false,
            ),
          ),
          Column(
            children: [
              // Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _LetterFilter.values.map((f) {
                      final isSelected = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(
                            f.label,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.petalWhite
                                  : AppColors.roseQuartz,
                            ),
                          ),
                          selectedColor: AppColors.deepRose.withValues(
                            alpha: 0.4,
                          ),
                          backgroundColor: AppColors.velvet.withValues(
                            alpha: 0.5,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.blushGold.withValues(alpha: 0.5)
                                : AppColors.moonlight.withValues(alpha: 0.15),
                          ),
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Letter list
              Expanded(
                child: StreamBuilder<List<HiddenNote>>(
                  key: ValueKey(_streamVersion),
                  stream: _service.notes,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return EverglowErrorState(
                        message: 'Could not load letters',
                        onRetry: () => setState(() => _streamVersion++),
                        icon: Icons.mail_outline_rounded,
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.done && !snapshot.hasData) {
                      return EverglowErrorState(
                        message: 'Could not load letters',
                        onRetry: () => setState(() => _streamVersion++),
                        icon: Icons.cloud_off_rounded,
                      );
                    }

                    if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: 5,
                        itemBuilder: (_, _) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: EverglowSkeleton(
                            width: double.infinity,
                            height: 80,
                            radius: 16,
                          ),
                        ),
                      );
                    }

                    var notes = snapshot.data!;

                    // Apply filter
                    notes = notes.where((n) {
                      switch (_filter) {
                        case _LetterFilter.locked:
                          return !n.isUnlocked;
                        case _LetterFilter.unread:
                          return n.isUnlocked && !n.isRead;
                        case _LetterFilter.read:
                          return n.isRead;
                        case _LetterFilter.all:
                          return true;
                      }
                    }).toList();

                    // Apply search
                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      notes = notes
                          .where(
                            (n) =>
                                n.title.toLowerCase().contains(q) ||
                                n.content.toLowerCase().contains(q),
                          )
                          .toList();
                    }

                    if (notes.isEmpty) {
                      return EverglowEmptyState(
                        icon: Icons.mail_outline_rounded,
                        title: _filter == _LetterFilter.all
                            ? 'No letters yet'
                            : 'No ${_filter.label.toLowerCase()} letters',
                        subtitle: 'Check back later! 🌸',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        return _LetterListTile(
                          note: notes[index],
                          onTap: () => _openNote(notes[index]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) async {
    List<HiddenNote> allNotes;
    try {
      allNotes = await _service.notes.first;
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load letters: $e')),
      );
      return;
    }
    if (!mounted) return;

    final filtered = allNotes.where((n) {
      switch (_filter) {
        case _LetterFilter.locked:
          return !n.isUnlocked;
        case _LetterFilter.unread:
          return n.isUnlocked && !n.isRead;
        case _LetterFilter.read:
          return n.isRead;
        case _LetterFilter.all:
          return true;
      }
    }).toList();

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LetterArchiveSearchDelegate(
          notes: filtered,
          onNoteTap: (note) {
            Navigator.pop(context);
            _openNote(note);
          },
        ),
      ),
    );
  }

  void _openNote(HiddenNote note) {
    if (!note.isUnlocked) {
      _showLockedAlert(note);
      return;
    }

    if (!note.isRead) {
      _service.markAsRead(note.id);
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

  void _showLockedAlert(HiddenNote note) {
    final diff = note.unlockDate.difference(DateTime.now());
    final countdown = diff.inDays > 0
        ? '${diff.inDays} day${diff.inDays == 1 ? '' : 's'}'
        : diff.inHours > 0
        ? '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}'
        : 'soon';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.velvet,
        title: Text(
          'Still sealed 🤫',
          textAlign: TextAlign.center,
          style: AppTypography.cormorantBold.copyWith(fontSize: 22),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: AppColors.blushGold.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'This letter will unlock in $countdown.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'I\'ll wait 🌸',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.blushGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single letter row in the archive list.
class _LetterListTile extends StatelessWidget {
  final HiddenNote note;
  final VoidCallback onTap;

  const _LetterListTile({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocked = note.isUnlocked;
    final isNew = unlocked && !note.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isNew
                ? AppColors.deepRose.withValues(alpha: 0.2)
                : AppColors.velvet.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNew
                  ? AppColors.blushGold.withValues(alpha: 0.4)
                  : AppColors.moonlight.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? (isNew
                            ? AppColors.deepRose.withValues(alpha: 0.3)
                            : AppColors.velvet)
                      : AppColors.blushGold.withValues(alpha: 0.15),
                ),
                child: Icon(
                  unlocked
                      ? (note.isRead ? Icons.drafts_outlined : Icons.favorite)
                      : Icons.lock_outline,
                  size: 20,
                  color: unlocked
                      ? (isNew ? AppColors.deepRose : AppColors.roseQuartz)
                      : AppColors.blushGold,
                ),
              ),
              const SizedBox(width: 14),
              // Title + preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 14,
                        fontWeight: isNew ? FontWeight.bold : FontWeight.w500,
                        color: AppColors.petalWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unlocked
                          ? (note.content.length > 60
                                ? '${note.content.substring(0, 60)}...'
                                : note.content)
                          : 'Sealed until ${_formatDate(note.unlockDate)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.roseQuartz.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Countdown badge for locked
              if (!unlocked) ...[
                const SizedBox(width: 8),
                _CountdownBadge(unlockDate: note.unlockDate),
              ],
              // New dot
              if (isNew) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.blushGold,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blushGold.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Animated countdown badge for locked letters.
class _CountdownBadge extends StatelessWidget {
  final DateTime unlockDate;

  const _CountdownBadge({required this.unlockDate});

  @override
  Widget build(BuildContext context) {
    final diff = unlockDate.difference(DateTime.now());
    final text = diff.inDays > 0
        ? '${diff.inDays}d'
        : diff.inHours > 0
        ? '${diff.inHours}h'
        : 'Soon';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blushGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            size: 12,
            color: AppColors.blushGold,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.blushGold,
            ),
          ),
        ],
      ),
    );
  }
}

extension on _LetterFilter {
  String get label {
    switch (this) {
      case _LetterFilter.all:
        return 'All';
      case _LetterFilter.locked:
        return 'Locked';
      case _LetterFilter.unread:
        return 'Unread';
      case _LetterFilter.read:
        return 'Read';
    }
  }
}
