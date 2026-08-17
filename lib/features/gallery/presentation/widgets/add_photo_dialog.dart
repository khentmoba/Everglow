import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
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
  final GalleryService _galleryService = GalleryService();
  Uint8List? _imageBytes;
  String _fileName = '';
  bool _isUploading = false;
  bool _isSubmitEnabled = false;

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

      final photo = await _galleryService.uploadPhoto(
        imageBytes: _imageBytes!,
        fileName: _fileName,
        caption: _captionController.text.trim(),
        uploadedBy: username,
        userId: auth.uid ?? '',
      );

      if (mounted) {
        Navigator.pop(context, photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: AppTheme.deepRose,
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
          color: AppTheme.velvet,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.blushGold.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepRose.withValues(alpha: 0.3),
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
                    color: AppTheme.twilight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.blushGold.withValues(alpha: 0.2),
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
                              color: AppTheme.blushGold.withValues(alpha: 0.65),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Tap to choose a photo",
                              style: AppTypography.outfitWhite.copyWith(
                                color: AppTheme.petalWhite.withValues(
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
                  color: AppTheme.petalWhite,
                ),
                decoration: InputDecoration(
                  hintText: "Add a caption…",
                  hintStyle: AppTypography.outfitWhite.copyWith(
                    color: AppTheme.petalWhite.withValues(alpha: 0.65),
                  ),
                  filled: true,
                  fillColor: AppTheme.twilight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.blushGold.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.blushGold),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
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
                        color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitEnabled && !_isUploading
                        ? _upload
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.deepRose,
                      foregroundColor: AppTheme.petalWhite,
                      disabledBackgroundColor: AppTheme.deepRose.withValues(
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
                              color: AppTheme.petalWhite,
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
