import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/utils/pick_image_bytes.dart';
import '../../../data/services/creator_service.dart';
import '../../../domain/models/milestone.dart';

class CreatorMemoriesTab extends StatefulWidget {
  final CreatorService creatorService;

  const CreatorMemoriesTab({super.key, required this.creatorService});

  @override
  State<CreatorMemoriesTab> createState() => _CreatorMemoriesTabState();
}

class _CreatorMemoriesTabState extends State<CreatorMemoriesTab> {
  int _selectedSubTab = 0; // 0: Compose & Preview, 1: Timeline History

  // Form State
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _memoryDate = DateTime.now();
  MilestoneCategory _selectedCategory = MilestoneCategory.memory;
  final List<({Uint8List bytes, String name})> _pickedImages = [];
  bool _isSaving = false;
  bool _showLivePreview = true;

  // Editing state if updating an existing milestone
  String? _editingMilestoneId;
  List<String> _existingImageUrls = [];

  late Stream<List<Milestone>> _milestonesStream;

  @override
  void initState() {
    super.initState();
    try {
      _milestonesStream =
          widget.creatorService.watchMilestones(limit: 50);
    } catch (_) {
      // Test / offline fallback: Firebase unavailable in widget tests.
      _milestonesStream = Stream.value(const []);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_pickedImages.length + _existingImageUrls.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 4 photos per milestone'),
          backgroundColor: AppColors.velvet,
        ),
      );
      return;
    }

    final picked = await pickImageBytes();
    if (picked != null && picked.bytes.isNotEmpty) {
      setState(() {
        _pickedImages.add((
          bytes: picked.bytes,
          name: 'memory_${DateTime.now().millisecondsSinceEpoch}_${_pickedImages.length}.jpg',
        ));
      });
    }
  }

  void _startEditing(Milestone milestone) {
    setState(() {
      _editingMilestoneId = milestone.id;
      _titleController.text = milestone.title;
      _descController.text = milestone.description;
      _memoryDate = milestone.date;
      _selectedCategory = milestone.category;
      _existingImageUrls = List.from(milestone.imageUrls);
      _pickedImages.clear();
      _selectedSubTab = 0; // Switch to form
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMilestoneId = null;
      _existingImageUrls.clear();
      _titleController.clear();
      _descController.clear();
      _pickedImages.clear();
      _memoryDate = DateTime.now();
      _selectedCategory = MilestoneCategory.memory;
    });
  }

  Future<void> _saveMemory() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthService>();
    final author = auth.currentUser;
    final uid = auth.uid ?? '';

    setState(() => _isSaving = true);
    try {
      final List<String> finalUrls = List.from(_existingImageUrls);

      if (_pickedImages.isNotEmpty) {
        final uploaded = await widget.creatorService.uploadMultipleImages(
          _pickedImages,
          uid,
        );
        finalUrls.addAll(uploaded);
      }

      if (_editingMilestoneId != null) {
        await widget.creatorService.updateMilestone(
          id: _editingMilestoneId!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          date: _memoryDate,
          imageUrls: finalUrls,
          author: author,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Milestone updated ✨'),
              backgroundColor: AppColors.velvet,
            ),
          );
        }
      } else {
        await widget.creatorService.saveMilestone(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          date: _memoryDate,
          imageUrls: finalUrls,
          author: author,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Memory saved to Everglow ✨'),
              backgroundColor: AppColors.velvet,
            ),
          );
        }
      }

      if (mounted) {
        _cancelEditing();
        setState(() => _selectedSubTab = 1); // View timeline list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving memory: $e'),
            backgroundColor: AppColors.velvet,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDeleteMilestone(Milestone milestone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelGlass,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        title: Text(
          'Delete Milestone?',
          style: AppTypography.outfitHeading.copyWith(
            fontSize: 16,
            color: AppColors.petalWhite,
          ),
        ),
        content: Text(
          'Delete "${milestone.title}" from your relationship timeline?',
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
        await widget.creatorService.deleteMilestone(milestone.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Milestone deleted'),
              backgroundColor: AppColors.velvet,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete milestone: $e'),
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
        // Sub-navigation: Compose & Preview vs History
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
                    icon: Icons.add_photo_alternate_rounded,
                    label: _editingMilestoneId != null
                        ? 'Edit Memory'
                        : 'New Memory',
                  ),
                ),
                Expanded(
                  child: _buildSubTabButton(
                    index: 1,
                    icon: Icons.auto_stories_rounded,
                    label: 'Timeline History',
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _selectedSubTab == 0
              ? _buildComposeView()
              : _buildHistoryView(),
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
            if (_editingMilestoneId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.blushGold.withValues(alpha: 0.15),
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: AppColors.blushGold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Editing Milestone',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 12,
                          color: AppColors.petalWhite,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelEditing,
                      child: Text(
                        'Cancel',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 12,
                          color: AppColors.auroraRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Category Chips
            Text(
              'Memory Category',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 13,
                color: AppColors.textHigh,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: MilestoneCategory.values.map((c) {
                  final isSelected = _selectedCategory == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text('${c.emoji} ${c.displayName}'),
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
                      onSelected: (_) => setState(() => _selectedCategory = c),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            _buildTextField(
              controller: _titleController,
              label: 'What happened?',
              hint: 'e.g., Our First Trip to Tagaytay',
              icon: Icons.auto_awesome_rounded,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),

            _buildTextField(
              controller: _descController,
              label: 'Tell the story...',
              hint: 'Write down the little details you never want to forget...',
              icon: Icons.history_edu_rounded,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),

            _buildDatePicker(),
            const SizedBox(height: 20),

            _buildMultiImagePicker(),
            const SizedBox(height: 24),

            // Live Preview Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: AppColors.blushGold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live Card Preview',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 13,
                        color: AppColors.petalWhite,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _showLivePreview,
                  activeTrackColor: AppColors.blushGold,
                  onChanged: (v) => setState(() => _showLivePreview = v),
                ),
              ],
            ),

            if (_showLivePreview) ...[
              const SizedBox(height: 10),
              _buildLivePreviewCard(),
            ],

            const SizedBox(height: 24),
            _buildSubmitButton(
              onPressed: _isSaving ? null : _saveMemory,
              isLoading: _isSaving,
              label: _editingMilestoneId != null
                  ? 'Update Milestone ✨'
                  : 'Save to Everglow ✨',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When was this?',
          style: AppTypography.outfitBold.copyWith(
            fontSize: 13,
            color: AppColors.textHigh,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _memoryDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
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
            if (picked != null) setState(() => _memoryDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.velvet.withValues(alpha: 0.55),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: AppColors.blushGold,
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM dd, yyyy').format(_memoryDate),
                  style: AppTypography.outfitWhite.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiImagePicker() {
    final totalCount = _existingImageUrls.length + _pickedImages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photos ($totalCount/4)',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 13,
                color: AppColors.textHigh,
              ),
            ),
            if (totalCount < 4)
              GestureDetector(
                onTap: _pickImage,
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 16,
                      color: AppColors.blushGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add Photo',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 12,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_existingImageUrls.isEmpty && _pickedImages.isEmpty)
          InkWell(
            onTap: _pickImage,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.velvet.withValues(alpha: 0.55),
                borderRadius: AppRadius.radiusLg,
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 28,
                      color: AppColors.blushGold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to pick 1-4 milestone photos',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Existing remote images
                ..._existingImageUrls.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final url = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.radiusMd,
                          child: Image.network(
                            url,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 90,
                              height: 90,
                              color: AppColors.velvet,
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _existingImageUrls.removeAt(idx),
                            ),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Newly picked local bytes
                ..._pickedImages.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.radiusMd,
                          child: Image.memory(
                            item.bytes,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _pickedImages.removeAt(idx)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                if (_existingImageUrls.length + _pickedImages.length < 4)
                  InkWell(
                    onTap: _pickImage,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.velvet.withValues(alpha: 0.55),
                        borderRadius: AppRadius.radiusMd,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLivePreviewCard() {
    final title = _titleController.text.trim().isEmpty
        ? 'Our Precious Milestone'
        : _titleController.text.trim();
    final story = _descController.text.trim().isEmpty
        ? 'Your story details will preview here live as you type...'
        : _descController.text.trim();
    final dateStr = DateFormat('MMMM dd, yyyy').format(_memoryDate);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.velvet.withValues(alpha: 0.7),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_selectedCategory.emoji} ${_selectedCategory.displayName}',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppColors.blushGold,
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 16,
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            story,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 13,
              color: AppColors.textMedium,
              height: 1.4,
            ),
          ),
          if (_pickedImages.isNotEmpty || _existingImageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: AppRadius.radiusMd,
              child: _pickedImages.isNotEmpty
                  ? Image.memory(
                      _pickedImages.first.bytes,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      _existingImageUrls.first,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return StreamBuilder<List<Milestone>>(
      stream: _milestonesStream,
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

        final milestones = snapshot.data ?? [];
        if (milestones.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 48,
                    color: AppColors.blushGold.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Milestones Found',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 16,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add your first relationship memory in the New Memory tab.',
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
          itemCount: milestones.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final m = milestones[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.velvet.withValues(alpha: 0.5),
                borderRadius: AppRadius.radiusLg,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${m.category.emoji} ${DateFormat('MMM dd, yyyy').format(m.date)}',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 11,
                          color: AppColors.blushGold,
                        ),
                      ),
                      const Spacer(),
                      // Edit button
                      IconButton(
                        tooltip: 'Edit memory',
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.blushGold,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _startEditing(m),
                      ),
                      // Delete button
                      IconButton(
                        tooltip: 'Delete memory',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.auroraRose,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmDeleteMilestone(m),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.title,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 15,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                  if (m.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${m.imageUrls.length} photo${m.imageUrls.length == 1 ? '' : 's'}',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
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
    void Function(String)? onChanged,
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
          onChanged: onChanged,
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
