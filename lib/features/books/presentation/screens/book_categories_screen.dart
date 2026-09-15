import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/shelf/atmospheric_backdrop.dart';
import '../../../../shared/widgets/shelf/shelf_icon_button.dart';
import '../widgets/book_categories.dart';

const _cBlack = AppColors.animeBackground;
const _cCard = AppColors.shimmerBase;
const _cWhite = AppColors.petalWhite;
const _cMuted = AppColors.mutedPurple;

/// Z-Library style category browse: every shelf in one grid.
/// Tapping a tile opens the full category list page.
class BookCategoriesScreen extends StatelessWidget {
  const BookCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final columns = AppBreakpoint.isDesktop(context)
        ? 4
        : (AppBreakpoint.isTablet(context) ? 3 : 2);
    return Scaffold(
      backgroundColor: _cBlack,
      body: Stack(
        children: [
          const ShelfAtmosphericBackdrop(
            glows: [
              RadialGlow(
                color: AppColors.warmAmber,
                alignment: Alignment(-0.7, -0.85),
                size: 0.85,
                opacity: 0.14,
              ),
              RadialGlow(
                color: AppColors.deepRose,
                alignment: Alignment(0.85, 0.95),
                size: 0.8,
                opacity: 0.10,
              ),
            ],
          ),
          SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 14, 20, 0),
                  child: Row(
                    children: [
                      ShelfIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        semanticLabel: 'Back',
                        tooltip: 'Back',
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Categories',
                              style: AppTypography.cormorantExtraBold.copyWith(
                                fontSize: 26,
                                color: _cWhite,
                              ),
                            ),
                            Text(
                              'PICK A SHELF',
                              style: AppTypography.outfitHeading.copyWith(
                                fontSize: 9,
                                color: _cMuted,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: bookCategories.length,
                    itemBuilder: (context, index) {
                      final category = bookCategories[index];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push(
                            '/books/category',
                            extra: category,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _cCard.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: category.color.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: category.color.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: category.color.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  category.icon,
                                  color: category.color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  category.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.outfitBold.copyWith(
                                    color: _cWhite,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Browse',
                                style: AppTypography.outfitWhite.copyWith(
                                  color: _cMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
