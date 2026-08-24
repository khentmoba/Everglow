import 'package:flutter/material.dart';
import '../../data/models/book_item.dart';
import '../../../../core/theme/app_typography.dart';

/// Reusable book cover card. Designed for grid placement (search
/// results, our-books list, etc.) — portrait orientation with a
/// gradient caption bar for the title and author.
class BookCoverCard extends StatelessWidget {
  final BookItem item;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final String? statusBadge;
  final Color? badgeColor;

  const BookCoverCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width,
    this.height,
    this.statusBadge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.coverUrl.isNotEmpty)
                Image.network(
                  item.coverUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 300,
                  errorBuilder: (_, _, _) => _placeholder(),
                )
              else
                _placeholder(),
              // Gradient overlay for the title
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.outfitHeading.copyWith(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.author.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.author,
                          style: AppTypography.outfitWhite.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (statusBadge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.deepPurple,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: (badgeColor ?? Colors.deepPurple).withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      statusBadge!,
                      style: AppTypography.outfitWhite.copyWith(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B33), Color(0xFF1A1A2E)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFFF4C2C2),
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitBold.copyWith(
                  color: const Color(0xFFFFF5F5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
