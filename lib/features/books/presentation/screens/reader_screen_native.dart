import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/book_item.dart';

/// Native fallback for the in-app web reader screen.
class ReaderScreen extends StatelessWidget {
  final BookItem book;
  final bool startListening;

  const ReaderScreen({
    super.key,
    required this.book,
    this.startListening = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.twilight,
      appBar: AppBar(
        title: const Text('Reader'),
        backgroundColor: AppColors.velvet,
        foregroundColor: AppColors.petalWhite,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 72,
                color: AppColors.auroraRose,
              ),
              const SizedBox(height: 20),
              Text(
                book.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.petalWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The in-app reader is available in the web app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedPurple, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
