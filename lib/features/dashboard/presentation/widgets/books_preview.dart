import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/services/open_library_service.dart';
import 'package:everglow/features/books/presentation/screens/books_screen.dart';
import 'package:everglow/services/auth_service.dart';

/// Dashboard sliver that previews the user's read list. Mirrors
/// `CinemaPreview` from the cinema feature.
class BooksPreview extends StatelessWidget {
  const BooksPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = OpenLibraryService();
    final userName = context.watch<AuthService>().currentUser ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Our Books',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.roseQuartz,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BooksScreen()),
                ),
                child: Text(
                  'View All',
                  style: GoogleFonts.outfit(
                    color: AppTheme.blushGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: userName.isEmpty
                ? _buildEmptyState(context)
                : StreamBuilder<List<BookItem>>(
                    stream: service.getReadListStream(userName),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _buildEmptyState(context);
                      }
                      final items = snapshot.data!.take(5).toList();
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ZoomIn(
                            delay: Duration(milliseconds: index * 100),
                            child: Container(
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.deepRose
                                        .withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: item.coverUrl.isNotEmpty
                                    ? Image.network(item.coverUrl,
                                        fit: BoxFit.cover)
                                    : Container(
                                        color: AppTheme.velvet,
                                        child: const Center(
                                          child: Icon(
                                            Icons.menu_book_rounded,
                                            color: AppTheme.roseQuartz,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.moonlight.withValues(alpha: 0.15), width: 1),
      ),
      child: Center(
        child: Text(
          'No books yet. Find your next read!',
          style: GoogleFonts.outfit(
            color: AppTheme.roseQuartz.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
