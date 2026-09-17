import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_empty_state.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../../../shared/widgets/everglow/everglow_stream_view.dart';
import '../../data/services/motchi_minis_service.dart';
import '../../data/services/study_artifact.dart';
import '../../domain/models/mini_game.dart';
import '../widgets/canvas_preview_sheet.dart';

/// Motchi's Minis — saved mini-games, ready to replay.
///
/// Games land here from the Save button in the canvas preview. Tapping a
/// mini reopens the same sandboxed preview it was saved from.
class MotchiMinisScreen extends StatefulWidget {
  const MotchiMinisScreen({super.key});

  @override
  State<MotchiMinisScreen> createState() => _MotchiMinisScreenState();
}

class _MotchiMinisScreenState extends State<MotchiMinisScreen> {
  final MotchiMinisService _service = MotchiMinisService();

  String _savedBy(String username) {
    return switch (username) {
      'khentsgdz' => 'Dada',
      'clairjassen' => 'Mama',
      _ => 'Motchi',
    };
  }

  String _savedOn(DateTime? date) {
    if (date == null) return 'just now';
    return DateFormat('MMM d').format(date);
  }

  Future<void> _delete(MiniGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.velvet,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        title: Text('Remove this game?', style: AppTypography.titleMedium()),
        content: Text(
          '"${game.title}" will leave the shelf. Motchi can always build it again.',
          style: AppTypography.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep',
              style: AppTypography.bodyMedium().copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: AppTypography.bodyMedium().copyWith(
                color: AppColors.auroraRose,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _service.deleteMini(game.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed from the shelf', style: AppTypography.bodySmall()),
        backgroundColor: AppColors.velvet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        margin: const EdgeInsets.all(AppSpacing.lg),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraLilac,
                  alignment: Alignment(-0.7, -0.9),
                  size: 0.9,
                  opacity: 0.14,
                ),
                RadialGlow(
                  color: AppColors.deepRose,
                  alignment: Alignment(0.9, 0.9),
                  size: 0.8,
                  opacity: 0.10,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(
                  title: "Motchi's Minis",
                  subtitle: 'saved games · made for you two',
                  icon: Icons.sports_esports_rounded,
                  hue: AppColors.auroraRose,
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: EverglowStreamView<List<MiniGame>>(
                    stream: _service.watchMinis(),
                    streamLabel: 'motchi-minis',
                    errorMessage: 'Could not load saved games',
                    errorIcon: Icons.sports_esports_outlined,
                    onRetry: () => setState(() {}),
                    loadingView: const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
                      child: Column(
                        children: [
                          EverglowSkeleton(
                            width: double.infinity,
                            height: 84,
                            radius: 20,
                          ),
                          SizedBox(height: 12),
                          EverglowSkeleton(
                            width: double.infinity,
                            height: 84,
                            radius: 20,
                          ),
                        ],
                      ),
                    ),
                    builder: (context, games) {
                      if (games.isEmpty) {
                        return EverglowEmptyState(
                          icon: Icons.sports_esports_rounded,
                          title: 'No saved games yet',
                          subtitle:
                              'Ask Motchi to build you a game, then tap Save in the preview 🍡',
                          ctaLabel: 'Ask Motchi',
                          onCta: () => context.push('/motchi'),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: games.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (_, i) {
                          final game = games[i];
                          return _MiniTile(
                            game: game,
                            subtitle:
                                '${_savedBy(game.createdBy)} · ${_savedOn(game.createdAt)}',
                            onPlay: () => openCanvasPreview(
                              context,
                              HtmlArtifact(
                                title: game.title,
                                html: game.html,
                              ),
                            ),
                            onDelete: () => _delete(game),
                          );
                        },
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

class _MiniTile extends StatelessWidget {
  final MiniGame game;
  final String subtitle;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _MiniTile({
    required this.game,
    required this.subtitle,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        borderRadius: AppRadius.radiusXl,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.inkDeep.withValues(alpha: 0.88),
            borderRadius: AppRadius.radiusXl,
            border: Border.all(
              color: AppColors.auroraRose.withValues(alpha: 0.22),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.auroraRose, AppColors.auroraGold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.auroraRose.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  size: 24,
                  color: AppColors.petalWhite,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game.title.isEmpty ? 'Motchi Mini' : game.title,
                      style: AppTypography.bodyMedium().copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.petalWhite,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall().copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.deepRose, AppColors.auroraRose],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.radiusFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Play',
                      style: AppTypography.bodySmall().copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.petalWhite,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.petalWhite,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from shelf',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                ),
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
