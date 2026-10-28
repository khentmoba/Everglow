import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/logger.dart';
import '../../data/services/torrent_index_service.dart';
import 'netflix/netflix_colors.dart';

/// Opens the download sheet for the title currently on screen.
///
/// Copies come from [TorrentIndexService]; every action here is real —
/// open the magnet in a torrent app, or copy it for one.
Future<void> showTorrentDownloadSheet(
  BuildContext context, {
  required int tmdbId,
  required String mediaType,
  required String title,
  int? season,
  int? episode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NetflixColors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.x2)),
    ),
    builder: (_) => TorrentDownloadSheet(
      tmdbId: tmdbId,
      mediaType: mediaType,
      title: title,
      season: season,
      episode: episode,
    ),
  );
}

/// Lists downloadable copies of one title, best seeded first.
class TorrentDownloadSheet extends StatefulWidget {
  const TorrentDownloadSheet({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.season,
    this.episode,
    this.service,
  });

  final int tmdbId;
  final String mediaType;
  final String title;
  final int? season;
  final int? episode;

  /// Injected in tests; production builds the real index client.
  final TorrentIndexService? service;

  @override
  State<TorrentDownloadSheet> createState() => _TorrentDownloadSheetState();
}

class _TorrentDownloadSheetState extends State<TorrentDownloadSheet> {
  late final TorrentIndexService _service =
      widget.service ?? TorrentIndexService();
  late Future<TorrentSearch> _search;
  final Set<String> _copiedHashes = {};

  @override
  void initState() {
    super.initState();
    _search = _load();
  }

  Future<TorrentSearch> _load() => _service.search(
    tmdbId: widget.tmdbId,
    mediaType: widget.mediaType,
    season: widget.season,
    episode: widget.episode,
  );

  void _retry() => setState(() => _search = _load());

  Future<void> _copy(TorrentCopy copy) async {
    await Clipboard.setData(ClipboardData(text: copy.magnet));
    if (!mounted) return;
    setState(() => _copiedHashes.add(copy.infoHash));
  }

  /// Hand the magnet to whatever torrent app the device has. Desktop and
  /// most Android phones answer; iPhone has no handler, so the link is
  /// copied instead of failing silently.
  Future<void> _open(TorrentCopy copy) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(copy.magnet),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      Logger.e('[TorrentDownload] no torrent app for this magnet', error: e);
    }
    if (!launched) await _copy(copy);
  }

  @override
  Widget build(BuildContext context) {
    final episode =
        widget.mediaType == 'tv' &&
            widget.season != null &&
            widget.episode != null
        ? 'S${widget.season} E${widget.episode}'
        : null;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NetflixColors.hairline,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode == null ? 'Download' : 'Download · $episode',
                          style: AppTypography.outfitHeading.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(
                            color: NetflixColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<TorrentSearch>(
                future: _search,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _SheetLoading();
                  }
                  final result = snapshot.data;
                  if (result == null || result.isEmpty) {
                    return _SheetEmpty(
                      message:
                          result?.reason ?? 'No copies found for this title.',
                      onRetry: _retry,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    itemCount: result.copies.length,
                    itemBuilder: (context, index) {
                      final copy = result.copies[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CopyTile(
                          copy: copy,
                          copied: _copiedHashes.contains(copy.infoHash),
                          onTap: () => _open(copy),
                          onCopy: () => _copy(copy),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                'Copies open in a torrent app. No app on this device? '
                'Copy the link and paste it there.',
                textAlign: TextAlign.center,
                style: AppTypography.outfitMuted.copyWith(
                  color: NetflixColors.textMuted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyTile extends StatelessWidget {
  const _CopyTile({
    required this.copy,
    required this.copied,
    required this.onTap,
    required this.onCopy,
  });

  final TorrentCopy copy;
  final bool copied;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (copy.size.isNotEmpty) copy.size,
      if (copy.seeders > 0) '${copy.seeders} seeds',
      if (copy.provider.isNotEmpty) copy.provider,
    ].join(' · ');
    return Material(
      color: NetflixColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              if (copy.quality.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: NetflixColors.hairline),
                  ),
                  child: Text(
                    copy.quality,
                    style: AppTypography.outfitHeading.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.filename,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitMuted.copyWith(
                            color: NetflixColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: copied ? 'Copied' : 'Copy link',
                onPressed: onCopy,
                icon: Icon(
                  copied ? Icons.check_rounded : Icons.link_rounded,
                  size: 18,
                ),
                color: copied ? NetflixColors.match : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLoading extends StatelessWidget {
  const _SheetLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 14),
          Text(
            'Looking for copies…',
            style: AppTypography.outfitMuted.copyWith(
              color: NetflixColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetEmpty extends StatelessWidget {
  const _SheetEmpty({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 30,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.download_for_offline_outlined,
            color: Colors.white38,
            size: 30,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.outfitWhite.copyWith(
              color: NetflixColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
