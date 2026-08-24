import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../../../shared/utils/pick_image_bytes.dart';
import '../../data/services/creator_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../cinema/presentation/widgets/tmdb_search_modal.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

class CreatorModal extends StatefulWidget {
  const CreatorModal({super.key});

  @override
  State<CreatorModal> createState() => _CreatorModalState();
}

class _CreatorModalState extends State<CreatorModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _creatorService = CreatorService();

  // Add Memory Form State
  final _memoryFormKey = GlobalKey<FormState>();
  final _memoryTitleController = TextEditingController();
  final _memoryDescController = TextEditingController();
  DateTime _memoryDate = DateTime.now();
  Uint8List? _memoryImageBytes;
  String? _memoryImageName;
  bool _isSavingMemory = false;

  // Drop Letter Form State
  final _letterFormKey = GlobalKey<FormState>();
  final _letterTitleController = TextEditingController();
  final _letterContentController = TextEditingController();
  DateTime _letterUnlockDate = DateTime.now().add(const Duration(days: 1));
  bool _isSavingLetter = false;
  String? _selectedTemplate;

  // Letter templates
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
      'icon': '🙏',
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
      'icon': '🌈',
      'title': 'Our Future Together',
      'content':
          'I dream about all the adventures we\'ll share, the places we\'ll go, and the memories we\'ll create. Here\'s what I hope for us...',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _memoryTitleController.dispose();
    _memoryDescController.dispose();
    _letterTitleController.dispose();
    _letterContentController.dispose();
    super.dispose();
  }

  Future<void> _pickMemoryImage() async {
    final bytes = (await pickImageBytes())?.bytes;
    if (bytes != null) {
      setState(() {
        _memoryImageBytes = bytes;
        _memoryImageName =
            'memory_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    }
  }

  Future<void> _saveMemory() async {
    if (!_memoryFormKey.currentState!.validate()) return;

    final author = context.read<AuthService>().currentUser;

    setState(() => _isSavingMemory = true);

    try {
      List<String> imageUrls = [];
      if (_memoryImageBytes != null && _memoryImageName != null) {
        final auth = context.read<AuthService>();
        final url = await _creatorService.uploadImage(
          _memoryImageBytes!,
          _memoryImageName!,
          auth.uid ?? '',
        );
        if (url != null) imageUrls.add(url);
      }

      await _creatorService.saveMilestone(
        title: _memoryTitleController.text,
        description: _memoryDescController.text,
        date: _memoryDate,
        imageUrls: imageUrls,
        author: author,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory saved to Everglow ✨')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingMemory = false);
    }
  }

  Future<void> _saveLetter() async {
    if (!_letterFormKey.currentState!.validate()) return;

    setState(() => _isSavingLetter = true);

    try {
      await _creatorService.saveHiddenNote(
        title: _letterTitleController.text,
        content: _letterContentController.text,
        unlockDate: _letterUnlockDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Letter dropped into the Letterbox 💌')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingLetter = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: BoxDecoration(
        color: AppColors.panelGlass,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicatorColor: AppColors.blushGold,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.petalWhite,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: AppTypography.outfitBold.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
            tabs: const [
              Tab(text: 'Add Memory'),
              Tab(text: 'Drop a Letter'),
              Tab(text: 'Cinema'),
              Tab(text: 'System'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAddMemoryForm(),
                _buildDropLetterForm(),
                _buildCinemaForm(),
                _buildSystemPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMemoryForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _memoryFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _memoryTitleController,
              label: 'What happened?',
              hint: 'e.g., Our First Picnic',
              icon: Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _memoryDescController,
              label: 'Tell the story...',
              hint: 'Write down the details you never want to forget.',
              icon: Icons.history_edu_rounded,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            _buildDatePicker(
              label: 'When was this?',
              currentDate: _memoryDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _memoryDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _memoryDate = picked);
              },
            ),
            const SizedBox(height: 24),
            _buildImagePicker(),
            const SizedBox(height: 32),
            _buildSubmitButton(
              onPressed: _isSavingMemory ? null : _saveMemory,
              isLoading: _isSavingMemory,
              label: 'Save to Everglow ✨',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropLetterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _letterFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Template picker
            Text(
              'Start from a template (optional)',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 14,
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
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.petalWhite
                            : AppColors.textMedium,
                      ),
                      selectedColor: AppColors.deepRose.withValues(alpha: 0.24),
                      backgroundColor: AppColors.velvet.withValues(alpha: 0.38),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.deepRose.withValues(alpha: 0.42)
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusFull,
                      ),
                      onSelected: (_) {
                        setState(() {
                          if (isSelected) {
                            _selectedTemplate = null;
                            _letterTitleController.clear();
                            _letterContentController.clear();
                          } else {
                            _selectedTemplate = t['name'];
                            _letterTitleController.text = t['title']!;
                            _letterContentController.text = t['content']!;
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _letterTitleController,
              label: 'Letter Title',
              hint: 'e.g., Read this when you miss me',
              icon: Icons.title_rounded,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _letterContentController,
              label: 'Secret Message',
              hint: 'Pour your heart out...',
              icon: Icons.favorite_outline_rounded,
              maxLines: 6,
            ),
            const SizedBox(height: 20),
            _buildDatePicker(
              label: 'When should this unlock?',
              currentDate: _letterUnlockDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _letterUnlockDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _letterUnlockDate = picked);
              },
            ),
            const SizedBox(height: 32),
            _buildSubmitButton(
              onPressed: _isSavingLetter ? null : _saveLetter,
              isLoading: _isSavingLetter,
              label: 'Drop the Letter 💌',
            ),
          ],
        ),
      ),
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
            fontSize: 14,
            color: AppColors.textHigh,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.outfitWhite.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.outfitWhite.copyWith(
              fontSize: 14,
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
              value == null || value.isEmpty ? 'Please fill this in' : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime currentDate,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.outfitBold.copyWith(
            fontSize: 14,
            color: AppColors.textHigh,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
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
                  DateFormat('MMMM dd, yyyy').format(currentDate),
                  style: AppTypography.outfitWhite.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add a Photo',
          style: AppTypography.outfitBold.copyWith(
            fontSize: 14,
            color: AppColors.textHigh,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickMemoryImage,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.velvet.withValues(alpha: 0.55),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: _memoryImageBytes != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          _memoryImageBytes!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black26,
                          radius: 12,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.petalWhite,
                            ),
                            onPressed: () => setState(() {
                              _memoryImageBytes = null;
                              _memoryImageName = null;
                            }),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 32,
                          color: AppColors.blushGold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to pick an image',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildCinemaForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.movie_creation_outlined,
            size: 60,
            color: AppColors.auroraRose.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 16),
          Text(
            'Movie Night Planner',
            textAlign: TextAlign.center,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for movies and TV shows to add to our shared watch list.',
            textAlign: TextAlign.center,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 40),
          _buildSubmitButton(
            onPressed: () {
              Navigator.pop(context); // Close CreatorModal
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const TMDBSearchModal(),
              );
            },
            isLoading: false,
            label: 'Search TMDB 🍿',
          ),
        ],
      ),
    );
  }

  Widget _buildSystemPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.tune_rounded,
            size: 60,
            color: AppColors.softLavender.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 16),
          Text(
            'System Tools',
            textAlign: TextAlign.center,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.petalWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Maintenance actions for the Everglow workspace.',
            textAlign: TextAlign.center,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
