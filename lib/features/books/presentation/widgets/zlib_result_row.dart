import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../data/models/book_search_result.dart';

const _cBlack = AppColors.animeBackground;
const _cCard = AppColors.shimmerBase;
const _cRose = AppColors.roseQuartz;
const _cDeepRose = AppColors.deepRose;
const _cGold = AppColors.animeGold;
const _cWhite = AppColors.petalWhite;
const _cMuted = AppColors.mutedPurple;

/// Z-Library style dense search result row: small cover thumb, title,
/// author, one metadata line (extension · language · year · size),
/// and a single download action. Built for scanning long lists on a
/// phone — one tap opens the detail page, the download icon saves
/// straight to the device.
class ZlibResultRow extends StatelessWidget {
  final BookSearchResult result;
  final VoidCallback onOpen;
  final VoidCallback? onDownload;
  final VoidCallback onSave;

  const ZlibResultRow({
    super.key,
    required this.result,
    required this.onOpen,
    required this.onDownload,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onOpen();
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cCard.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cRose.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44,
                  height: 64,
                  child: result.coverUrl.isNotEmpty
                      ? AppNetworkImage(
                          imageUrl: result.coverUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 120,
                          errorWidget: Container(color: _cBlack),
                        )
                      : Container(
                          color: _cBlack,
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: _cMuted,
                            size: 18,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        color: _cWhite,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    if (result.author.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        result.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cDeepRose,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    _MetaLine(result: result),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _MiniAction(
                    icon: Icons.download_rounded,
                    tooltip: 'Download',
                    color: AppColors.cinemaGreen,
                    onTap: onDownload,
                  ),
                  const SizedBox(height: 6),
                  _MiniAction(
                    icon: Icons.bookmark_border_rounded,
                    tooltip: 'Save',
                    color: const Color(0xFF7B1FA2),
                    onTap: onSave,
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

/// One-line metadata in Z-Lib order: publisher/year, then the file
/// line (extension + size), then language. Dimmed gold so titles pop.
class _MetaLine extends StatelessWidget {
  final BookSearchResult result;
  const _MetaLine({required this.result});

  @override
  Widget build(BuildContext context) {
    final bits = <String>[];
    final pubYear = [
      if (result.publisher.isNotEmpty) result.publisher,
      if (result.year.isNotEmpty) result.year,
    ].join(', ');
    if (pubYear.isNotEmpty) bits.add(pubYear);
    if (result.fileLine.isNotEmpty) bits.add(result.fileLine);
    if (result.language.isNotEmpty) bits.add(result.language);
    if (bits.isEmpty) return const SizedBox.shrink();
    return Text(
      bits.join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.outfitWhite.copyWith(
        color: _cGold.withValues(alpha: 0.8),
        fontSize: 10.5,
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.3,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 15),
          ),
        ),
      ),
    );
  }
}
