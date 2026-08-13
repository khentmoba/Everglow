import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/animex_models.dart';
import '../../../data/services/animex_stores.dart';

import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_tokens.dart';

/// Watch history page with resume actions and per-entry removal.
class AnimeXHistoryPage extends StatelessWidget {
  final AnimeXController controller;

  const AnimeXHistoryPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<AnimexStores>();
    final history = stores.history;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History',
                    style: bebasStyle(size: 32, color: AnimeXTokens.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    history.isEmpty
                        ? 'Your watched anime appear here'
                        : '${history.length} watched',
                    style: dmSansStyle(
                      size: 13,
                      color: AnimeXTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (history.isNotEmpty)
              GestureDetector(
                onTap: () => stores.clearHistory(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                    border: Border.all(color: AnimeXTokens.border),
                  ),
                  child: Text(
                    'Clear All',
                    style: dmSansStyle(
                      size: 12.5,
                      color: AnimeXTokens.textSecondary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: AnimeXTokens.textMuted,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nothing watched yet',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 14,
                      color: AnimeXTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...history.map((e) => _HistoryRow(
                entry: e,
                onTap: () {
                  controller.openWatch(
                    mediaItemFromHistory(e),
                    episode: e.episode,
                  );
                },
                onRemove: () => stores.removeHistoryEntry(e.key),
              )),
        const SizedBox(height: 24),
        AnimeXFooter(controller: controller),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final AnimexHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _HistoryRow({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final progress = entry.episodeMinutes > 0
        ? (entry.durationSeconds / (entry.episodeMinutes * 60)).clamp(0.0, 1.0)
        : 0.0;
    final ago = _timeAgo(entry.updatedAt);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
            border: Border.all(color: AnimeXTokens.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                child: SizedBox(
                  width: 64,
                  height: 88,
                  child: entry.coverUrl.isEmpty
                      ? Container(color: AnimeXTokens.surfaceRaised)
                      : Image.network(
                          entry.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AnimeXTokens.surfaceRaised,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: dmSansStyle(
                        size: 14,
                        color: AnimeXTokens.textPrimary,
                        weight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'EP ${entry.episode} · $ago',
                      style: dmSansStyle(
                        size: 11.5,
                        color: AnimeXTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AnimeXTokens.accent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% · Resume EP ${entry.episode}',
                      style: dmSansStyle(
                        size: 11,
                        color: AnimeXTokens.accentWarm,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: AnimeXTokens.border),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AnimeXTokens.textSecondary,
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

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.day}/${time.month}/${time.year}';
}
