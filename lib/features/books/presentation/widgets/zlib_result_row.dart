import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/book_search_result.dart';
import 'book_cover_card.dart';

const _cCard = AppColors.shimmerBase;
const _cRose = AppColors.roseQuartz;
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
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            color: _cCard.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cRose.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: BookCover(
                  imageUrl: result.coverUrl,
                  title: result.title,
                  author: result.author,
                  radius: 5,
                  cacheWidth: 140,
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
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    if (result.author.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        result.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cRose.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
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
                    onTap: onDownload,
                  ),
                  const SizedBox(height: 4),
                  _MiniAction(
                    icon: Icons.bookmark_border_rounded,
                    tooltip: 'Save',
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
      style: AppTypography.outfitWhite.copyWith(color: _cMuted, fontSize: 11),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              color: _cRose.withValues(alpha: enabled ? 0.85 : 0.2),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
