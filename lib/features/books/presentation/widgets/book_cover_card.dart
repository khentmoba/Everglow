import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../data/models/book_item.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';

/// A book cover at 2:3. When the image is missing or fails (Gutenberg
/// covers often block web loads), it draws a cloth-bound cover with
/// the title and author instead of an empty box.
class BookCover extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String author;
  final double radius;
  final int cacheWidth;

  const BookCover({
    super.key,
    required this.imageUrl,
    required this.title,
    this.author = '',
    this.radius = 8,
    this.cacheWidth = 300,
  });

  static const _cloths = [
    AppColors.velvet,
    AppColors.plum,
    AppColors.silk,
    AppColors.deepBlack,
  ];

  @override
  Widget build(BuildContext context) {
    final fallback = _ClothCover(
      title: title,
      author: author,
      cloth: _cloths[title.hashCode.abs() % _cloths.length],
    );
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                AppNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  placeholder: fallback,
                  errorWidget: fallback,
                )
              else
                fallback,
              // Spine crease: a soft highlight on the left edge makes a
              // flat image read as a physical book.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.petalWhite.withValues(alpha: 0.2),
                        AppColors.petalWhite.withValues(alpha: 0),
                      ],
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
}

class _ClothCover extends StatelessWidget {
  final String title;
  final String author;
  final Color cloth;
  const _ClothCover({
    required this.title,
    required this.author,
    required this.cloth,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cloth, AppColors.inkDeep],
      ),
    );
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          // Thumbnails are too small to letter, so they get a book mark.
          if (box.maxWidth < 80) {
            return DecoratedBox(
              decoration: decoration,
              child: Icon(
                Icons.menu_book_rounded,
                color: AppColors.auroraGold.withValues(alpha: 0.6),
                size: box.maxWidth * 0.4,
              ),
            );
          }
          return _lettered(decoration);
        },
      ),
    );
  }

  Widget _lettered(BoxDecoration decoration) {
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.auroraGold.withValues(alpha: 0.35),
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        padding: const EdgeInsets.all(8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 110,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cormorantBold.copyWith(
                    color: AppColors.auroraGold,
                    fontSize: 17,
                    height: 1.1,
                  ),
                ),
                if (author.isNotEmpty) ...[
                  Container(
                    width: 18,
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: AppColors.auroraGold.withValues(alpha: 0.5),
                  ),
                  Text(
                    author.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitBold.copyWith(
                      color: AppColors.roseQuartz.withValues(alpha: 0.75),
                      fontSize: 8,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bookstore-style tile: the cover on top, title and author below.
/// Covers already print their own title, so nothing is laid over them.
class BookCoverCard extends StatelessWidget {
  final BookItem item;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  /// Small coloured label under the author, e.g. who has read it.
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
    return Semantics(
      button: true,
      label: item.author.isEmpty
          ? item.title
          : '${item.title}, by ${item.author}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Loose fit: the cover keeps its 2:3 size and the title sits
              // right under it; it only shrinks when the tile is too short.
              Flexible(
                child: BookCover(
                  imageUrl: item.coverUrl,
                  title: item.title,
                  author: item.author,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitBold.copyWith(
                  color: AppColors.petalWhite,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
              if (statusBadge != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: badgeColor ?? AppColors.roseQuartz,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          statusBadge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.mutedPurple,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (item.author.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.mutedPurple,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
