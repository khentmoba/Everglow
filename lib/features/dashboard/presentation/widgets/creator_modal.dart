import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../data/services/creator_service.dart';
import '../../../../services/auth_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/tmdb_search_modal.dart';

class CreatorModal extends StatefulWidget {
  const CreatorModal({super.key});

  @override
  State<CreatorModal> createState() => _CreatorModalState();
}

class _CreatorModalState extends State<CreatorModal> with SingleTickerProviderStateMixin {
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
    final bytes = await ImagePickerWeb.getImageAsBytes();
    if (bytes != null) {
      setState(() {
        _memoryImageBytes = bytes;
        _memoryImageName = 'memory_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    }
  }

  Future<void> _saveMemory() async {
    if (!_memoryFormKey.currentState!.validate()) return;
    
    setState(() => _isSavingMemory = true);

    try {
      List<String> imageUrls = [];
      if (_memoryImageBytes != null && _memoryImageName != null) {
        final url = await _creatorService.uploadImage(_memoryImageBytes!, _memoryImageName!);
        if (url != null) imageUrls.add(url);
      }

      await _creatorService.saveMilestone(
        title: _memoryTitleController.text,
        description: _memoryDescController.text,
        date: _memoryDate,
        imageUrls: imageUrls,
        author: context.read<AuthService>().currentUser,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory saved to Everglow ✨')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingLetter = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF0F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.pink.shade100,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.pinkAccent,
            labelColor: Colors.pinkAccent,
            unselectedLabelColor: Colors.pink.shade200,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
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
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.pink.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.pink.shade200),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) => value == null || value.isEmpty ? 'Please fill this in' : null,
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
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.pink.shade700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: Colors.pink.shade200),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM dd, yyyy').format(currentDate),
                  style: GoogleFonts.outfit(fontSize: 16),
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
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.pink.shade700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickMemoryImage,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.pink.shade50,
                width: 2,
              ),
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
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
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
                        Icon(Icons.add_photo_alternate_rounded, size: 32, color: Colors.pink.shade200),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to pick an image',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.pink.shade200,
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
        backgroundColor: Colors.pinkAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              label,
              style: GoogleFonts.outfit(
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
          Icon(Icons.movie_creation_outlined, size: 60, color: Colors.pink.shade100),
          const SizedBox(height: 16),
          Text(
            'Movie Night Planner',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.pink.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for movies and TV shows to add to our shared watch list.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.pink.shade300,
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

}
