import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/memory.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class AddMemoryForm extends StatefulWidget {
  final String userId;
  const AddMemoryForm({super.key, required this.userId});

  @override
  State<AddMemoryForm> createState() => _AddMemoryFormState();
}

class _AddMemoryFormState extends State<AddMemoryForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Uint8List? _selectedFileData;
  String? _selectedFileName;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final imageInfo = await ImagePickerWeb.getImageInfo;
    if (imageInfo != null && imageInfo.data != null) {
      setState(() {
        _selectedFileData = imageInfo.data;
        _selectedFileName = imageInfo.fileName;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.taupe,
              onPrimary: AppTheme.cream,
              onSurface: AppTheme.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imageUrl;
      if (_selectedFileData != null && _selectedFileName != null) {
        final storageService = Provider.of<StorageService>(context, listen: false);
        imageUrl = await storageService.uploadImage(
          _selectedFileData!,
          _selectedFileName!,
          widget.userId,
        );
      }

      final memory = Memory(
        id: '', // Firestore will assign this
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        category: 'Memories',
        date: _selectedDate,
        ownerId: widget.userId,
      );

      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.addMemory(memory);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cream,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEW MEMORY', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 32),
                
                // Image Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppTheme.taupe.withOpacity(0.2)),
                      ),
                      child: _selectedFileData != null
                          ? Image.memory(_selectedFileData!, fit: BoxFit.cover)
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, color: AppTheme.taupe, size: 48),
                                SizedBox(height: 8),
                                Text('Add a photo'),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Fields
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'The Story',
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date Picker Trigger
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('MMMM d, yyyy').format(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                
                const SizedBox(height: 48),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 120,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.charcoal,
                          foregroundColor: AppTheme.cream,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cream),
                              )
                            : const Text('SAVE'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
