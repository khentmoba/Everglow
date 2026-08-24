import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/milestone.dart';
import '../../../../core/theme/app_typography.dart';

class MemoryDetailOverlay extends StatelessWidget {
  final Milestone milestone;

  const MemoryDetailOverlay({super.key, required this.milestone});

  @override
  Widget build(BuildContext context) {
    final dialogContent = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.velvet.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppTheme.blushGold.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepRose.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        milestone.title,
                        style: AppTypography.cormorantBold.copyWith(
                          fontSize: 24,
                        ),
                      ),
                      Text(
                        DateFormat('MMMM d, yyyy').format(milestone.date),
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 14,
                          color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.roseQuartz),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (milestone.author != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.moonlight.withValues(
                          alpha: AppTheme.glassOpacity,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.moonlight.withValues(alpha: 0.18),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        "Memory by ${milestone.author} \u2661",
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.blushGold,
                        ),
                      ),
                    ),
                  Text(
                    milestone.description,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 16,
                      height: 1.6,
                      color: AppTheme.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: AppTheme.deepRose, size: 16),
                const SizedBox(width: 8),
                Text(
                  "Living Archive",
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    color: AppTheme.roseQuartz.withValues(alpha: 0.5),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.favorite, color: AppTheme.deepRose, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: AppMotion.reduced
          ? dialogContent
          : FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: dialogContent,
            ),
    );
  }
}
