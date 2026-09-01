import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/pick_image_bytes.dart';
import '../../data/services/gallery_service.dart';
import '../../../../core/theme/app_typography.dart';

class AddPhotoDialog extends StatefulWidget {
  const AddPhotoDialog({super.key});

  @override
  State<AddPhotoDialog> createState() => _AddPhotoDialogState();
}

class _AddPhotoDialogState extends State<AddPhotoDialog> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final GalleryService _galleryService = GalleryService();
  Uint8List? _imageBytes;
  String _fileName = '';
  bool _isUploading = false;
  bool _isSubmitEnabled = false;
  bool _addLocation = false;

  Future<void> _pickImage() async {
    final picked = await pickImageBytes();
    if (picked != null && mounted) {
      // Guess extension from file name, fallback to jpg
      String ext = 'jpg';
      if (picked.fileName != null && picked.fileName!.contains('.')) {
        ext = picked.fileName!.split('.').last.toLowerCase();
      }
      setState(() {
        _imageBytes = picked.bytes;
        _fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.$ext';
        _validateInput();
      });
    }
  }

  void _validateInput() {
    setState(() {
      _isSubmitEnabled = _imageBytes != null;
    });
  }

  Future<void> _upload() async {
    if (_imageBytes == null || _isUploading) return;

    setState(() => _isUploading = true);

    try {
      final auth = context.read<AuthService>();
      final username = auth.currentUser ?? 'unknown';

      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      final loc = _locationController.text.trim();
      final photo = await _galleryService.uploadPhoto(
        imageBytes: _imageBytes!,
        fileName: _fileName,
        caption: _captionController.text.trim(),
        uploadedBy: username,
        userId: auth.uid ?? '',
        latitude: _addLocation ? lat : null,
        longitude: _addLocation ? lng : null,
        locationName: _addLocation && loc.isNotEmpty ? loc : null,
        takenAt: DateTime.now(),
      );

      if (mounted) {
        Navigator.pop(context, photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: AppColors.deepRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        decoration: BoxDecoration(
          color: AppColors.velvet,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRose.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add Memory 📸",
                style: AppTypography.cormorantBold.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 20),

              // Image Preview / Pick Button
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.twilight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: _imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: AppColors.blushGold.withValues(alpha: 0.65),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Tap to choose a photo",
                              style: AppTypography.outfitWhite.copyWith(
                                color: AppColors.petalWhite.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Caption Input
              TextField(
                controller: _captionController,
                style: AppTypography.outfitWhite.copyWith(
                  color: AppColors.petalWhite,
                ),
                decoration: InputDecoration(
                  hintText: "Add a caption…",
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.65),
                  ),
                  filled: true,
                  fillColor: AppColors.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.blushGold.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.blushGold),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              // Location Toggle — Immich-inspired
              GestureDetector(
                onTap: () => setState(() => _addLocation = !_addLocation),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _addLocation
                        ? AppColors.blushGold.withValues(alpha: 0.12)
                        : AppColors.twilight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _addLocation
                          ? AppColors.blushGold
                          : AppColors.blushGold.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _addLocation
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: _addLocation
                            ? AppColors.blushGold
                            : AppColors.petalWhite.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.place_rounded,
                        size: 16,
                        color: _addLocation
                            ? AppColors.blushGold
                            : AppColors.petalWhite.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pin location (Immich map)',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          color: _addLocation
                              ? AppColors.blushGold
                              : AppColors.petalWhite.withValues(alpha: 0.7),
                          fontWeight: _addLocation
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_addLocation) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _locationController,
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Place name — e.g., Kyoto, Our bench',
                    hintStyle: AppTypography.outfitWhite.copyWith(
                      color: AppColors.petalWhite.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                    prefixIcon: Icon(
                      Icons.label_rounded,
                      size: 16,
                      color: AppColors.petalWhite.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: AppColors.twilight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.blushGold.withValues(alpha: 0.15),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Latitude',
                          hintStyle: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                          filled: true,
                          fillColor: AppColors.twilight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Longitude',
                          hintStyle: AppTypography.outfitWhite.copyWith(
                            color: AppColors.petalWhite.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                          filled: true,
                          fillColor: AppColors.twilight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tip: paste from Google Maps • leave empty to save without coords',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10,
                    color: AppColors.petalWhite.withValues(alpha: 0.4),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppColors.roseQuartz.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitEnabled && !_isUploading
                        ? _upload
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepRose,
                      foregroundColor: AppColors.petalWhite,
                      disabledBackgroundColor: AppColors.deepRose.withValues(
                        alpha: 0.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.petalWhite,
                            ),
                          )
                        : Text(
                            "Upload",
                            style: AppTypography.outfitWhite.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}