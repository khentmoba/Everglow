import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/services/creator_service.dart';
import '../../../domain/models/hidden_note.dart';

class CreatorLettersTab extends StatefulWidget {
  final CreatorService creatorService;

  const CreatorLettersTab({super.key, required this.creatorService});

  @override
  State<CreatorLettersTab> createState() => _CreatorLettersTabState();
}

class _CreatorLettersTabState extends State<CreatorLettersTab> {
  int _selectedSubTab = 0; // 0: Compose, 1: Vault / Scheduled

  // Form State
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime _unlockDate = DateTime.now().add(const Duration(days: 1));
  bool _isSaving = false;
  String? _selectedTemplate;

  late Stream<List<HiddenNote>> _notesStream;

  @override
  void initState() {
    super.initState();
    try {
      _notesStream = widget.creatorService.watchHiddenNotes(limit: 50);
    } catch (_) {
      // Test / offline fallback: Firebase unavailable in widget tests.
      _notesStream = Stream.value(const []);
    }
  }

  static const List<Map<String, String>> _letterTemplates = [
    {
      'name': 'Love Letter',
      'icon': '💌',
      'title': 'To My Love',
      'content':
          'I wanted to take a moment to tell you how much you mean to me. Every day with you feels like a beautiful dream I never want to wake up from...',
    },
    {
      'name': 'Appreciation',
      'icon': '🌸',
      'title': 'Thank You For Everything',
      'content':
          'I notice all the little things you do, and I want you to know how grateful I am. You make my world brighter in ways you probably don\'t even realize...',
    },
    {
      'name': 'Memory Recap',
      'icon': '⭐',
      'title': 'Remember When...',
      'content':
          'I was thinking about that time we... and it made me smile. I want to make sure we never forget these precious moments together...',
    },
    {
      'name': 'Future Dreams',
      'icon': '✨',
      'title': 'Our Future Together',
      'content':
          'I dream about all the adventures we\'ll share, the places we\'ll go, and the memories we\'ll create. Here\'s what I hope for us...',
    },
    {
      'name': 'Open When Sad',
      'icon': '🌧️',
      'title': 'Open This When You Need a Hug',
      'content':
          'Take a deep breath, my sweet love. Whatever is feeling heavy right now, remember that I am always here for you, always rooting for you, and holding your hand...',
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveLetter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await widget.creatorService.saveHiddenNote(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        unlockDate: _unlockDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Letter safely dropped into the Letterbox ✨'),
            backgroundColor: AppColors.velvet,
          ),
        );
        _titleController.clear();
        _contentController.clear();
        setState(() {
          _selectedTemplate = null;
          _selectedSubTab = 1; // Switch to vault to view the letter
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error dropping letter: $e'),
            backgroundColor: AppColors.velvet,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editUnlockDate(HiddenNote note) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: note.unlockDate.isAfter(DateTime.now())
          ? note.unlockDate
          : DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.blushGold,
              onPrimary: AppColors.twilight,
              surface: AppColors.twilight,
              onSurface: AppColors.petalWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      try {
        await widget.creatorService.updateHiddenNote(
          id: note.id,
          title: note.title,
          content: note.content,
          unlockDate: picked,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unlock date updated ✨'),
              backgroundColor: AppColors.velvet,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update date: $e'),
              backgroundColor: AppColors.velvet,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteNote(HiddenNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelGlass,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        title: Text(
          'Delete Letter?',
          style: AppTypography.outfitHeading.copyWith(
            fontSize: 16,
            color: AppColors.petalWhite,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${note.title}"? This cannot be undone.',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 13,
            color: AppColors.textMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.outfitMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: AppTypography.outfitBold.copyWith(
                color: AppColors.auroraRose,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await widget.creatorService.deleteHiddenNote(note.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Letter deleted'),
              backgroundColor: AppColors.velvet,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.velvet,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-navigation: Compose vs Vault
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.velvet.withValues(alpha: 0.6),
              borderRadius: AppRadius.radiusFull,
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubTabButton(
                    index: 0,
                    icon: Icons.edit_note_rounded,
                    label: 'Compose',
                  ),
                ),
                Expanded(
                  child: _buildSubTabButton(
                    index: 1,
                    icon: Icons.all_inbox_rounded,
                    label: 'Vault & Scheduled',
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _selectedSubTab == 0
              ? _buildComposeView()
              : _buildVaultView(),
        ),
      ],
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedSubTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.blushGold.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: AppRadius.radiusFull,
          border: isSelected
              ? Border.all(color: AppColors.blushGold.withValues(alpha: 0.4))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.blushGold : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 12,
                color: isSelected ? AppColors.petalWhite : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Template selection
            Text(
              'Start from a template',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 13,
                color: AppColors.textHigh,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _letterTemplates.map((t) {
                  final isSelected = _selectedTemplate == t['name'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text('${t['icon']} ${t['name']}'),
                      labelStyle: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.petalWhite
                            : AppColors.textMedium,
                      ),
                      selectedColor: AppColors.deepRose.withValues(alpha: 0.28),
                      backgroundColor: AppColors.velvet.withValues(alpha: 0.4),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.deepRose.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusFull,
                      ),
                      onSelected: (_) {
                        setState(() {
                          if (isSelected) {
                            _selectedTemplate = null;
                            _titleController.clear();
                            _contentController.clear();
                          } else {
                            _selectedTemplate = t['name'];
                            _titleController.text = t['title']!;
                            _contentController.text = t['content']!;
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            _buildTextField(
              controller: _titleController,
              label: 'Letter Title',
              hint: 'e.g., Read this when you miss me',
              icon: Icons.title_rounded,
            ),
            const SizedBox(height: 18),
            _buildTextField(
              controller: _contentController,
              label: 'Secret Message',
              hint: 'Pour your heart out...',
              icon: Icons.favorite_outline_rounded,
              maxLines: 6,
            ),
            const SizedBox(height: 18),
            _buildUnlockDatePicker(),
            const SizedBox(height: 24),
            _buildSubmitButton(
              onPressed: _isSaving ? null : _saveLetter,
              isLoading: _isSaving,
              label: 'Drop into Letterbox 💌',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Unlock Date & Time',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 13,
                color: AppColors.textHigh,
              ),
            ),
            // Quick preset chips
            Row(
              children: [
                _buildPresetChip('+1 Day', const Duration(days: 1)),
                const SizedBox(width: 6),
                _buildPresetChip('+1 Week', const Duration(days: 7)),
                const SizedBox(width: 6),
                _buildPresetChip('+1 Month', const Duration(days: 30)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _unlockDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.blushGold,
                      onPrimary: AppColors.twilight,
                      surface: AppColors.twilight,
                      onSurface: AppColors.petalWhite,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _unlockDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.velvet.withValues(alpha: 0.55),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 18,
                  color: AppColors.blushGold,
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM dd, yyyy').format(_unlockDate),
                  style: AppTypography.outfitWhite.copyWith(fontSize: 14),
                ),
                const Spacer(),
                Text(
                  _unlockDate.difference(DateTime.now()).inDays > 0
                      ? 'in ${_unlockDate.difference(DateTime.now()).inDays} days'
                      : 'today',
                  style: AppTypography.outfitMedium.copyWith(
                    fontSize: 12,
                    color: AppColors.blushGold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, Duration duration) {
    return GestureDetector(
      onTap: () => setState(() => _unlockDate = DateTime.now().add(duration)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.velvet.withValues(alpha: 0.4),
          borderRadius: AppRadius.radiusFull,
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.outfitMedium.copyWith(
            fontSize: 10,
            color: AppColors.textMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildVaultView() {
    return StreamBuilder<List<HiddenNote>>(
      stream: _notesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.blushGold),
            ),
          );
        }

        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 48,
                    color: AppColors.blushGold.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Letters in the Vault',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 16,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Write a secret letter in the Compose tab to surprise Clair!',
                    textAlign: TextAlign.center,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          itemCount: notes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final note = notes[index];
            final isUnlocked = note.isUnlocked;
            final isRead = note.isRead;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.velvet.withValues(alpha: 0.5),
                borderRadius: AppRadius.radiusLg,
                border: Border.all(
                  color: isRead
                      ? AppColors.border
                      : (isUnlocked
                          ? AppColors.deepRose.withValues(alpha: 0.4)
                          : AppColors.blushGold.withValues(alpha: 0.25)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isRead
                              ? AppColors.velvet.withValues(alpha: 0.8)
                              : (isUnlocked
                                  ? AppColors.deepRose.withValues(alpha: 0.25)
                                  : AppColors.blushGold.withValues(alpha: 0.15)),
                          borderRadius: AppRadius.radiusFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isRead
                                  ? Icons.visibility_rounded
                                  : (isUnlocked
                                      ? Icons.lock_open_rounded
                                      : Icons.lock_rounded),
                              size: 12,
                              color: isRead
                                  ? AppColors.textMuted
                                  : (isUnlocked
                                      ? AppColors.deepRose
                                      : AppColors.blushGold),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isRead
                                  ? 'Opened by Clair'
                                  : (isUnlocked
                                      ? 'Ready to Open'
                                      : 'Unlocks in ${note.unlockDate.difference(DateTime.now()).inDays}d'),
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 10,
                                color: isRead
                                    ? AppColors.textMuted
                                    : (isUnlocked
                                        ? AppColors.petalWhite
                                        : AppColors.blushGold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Edit Date Button
                      IconButton(
                        tooltip: 'Change unlock date',
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: AppColors.blushGold,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _editUnlockDate(note),
                      ),
                      // Delete Button
                      IconButton(
                        tooltip: 'Delete letter',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.auroraRose,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmDeleteNote(note),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    note.title,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 15,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Unlock date: ${DateFormat('MMM dd, yyyy').format(note.unlockDate)}',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.outfitBold.copyWith(
            fontSize: 13,
            color: AppColors.textHigh,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.outfitWhite.copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.outfitWhite.copyWith(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.velvet.withValues(alpha: 0.55),
            border: OutlineInputBorder(
              borderRadius: AppRadius.radiusLg,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.radiusLg,
              borderSide: BorderSide(
                color: AppColors.blushGold.withValues(alpha: 0.45),
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Please fill this in' : null,
        ),
      ],
    );
  }

  Widget _buildSubmitButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String label,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null
            ? AppColors.deepRose.withValues(alpha: 0.48)
            : AppColors.deepRose,
        foregroundColor: AppColors.petalWhite,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.petalWhite),
              ),
            )
          : Text(
              label,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
