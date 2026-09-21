import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../data/models/lastfm_image_utils.dart';
import '../../data/models/music_status.dart';
import '../providers/artist_showdown_provider.dart';
import 'listen_along_popup.dart';

/// Opens a vertical sheet (or dialog on desktop/tablet) displaying the
/// chronological scrobble history of [artist] for both Khent and Clair.
Future<void> showArtistShowdownHistory(
  BuildContext context, {
  required ArtistShowdownProvider showdown,
}) {
  final isWide = MediaQuery.of(context).size.width >= 640;

  final content = ChangeNotifierProvider<ArtistShowdownProvider>.value(
    value: showdown,
    child: const ArtistShowdownHistorySheet(),
  );

  if (isWide) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          child: content,
        ),
      ),
    );
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => ChangeNotifierProvider<ArtistShowdownProvider>.value(
        value: showdown,
        child: ArtistShowdownHistorySheet(scrollController: scrollController),
      ),
    ),
  );
}

enum _UserFilter { both, khent, clair }

/// Vertical timeline of listening history for an artist in the showdown.
class ArtistShowdownHistorySheet extends StatefulWidget {
  final ScrollController? scrollController;
  const ArtistShowdownHistorySheet({super.key, this.scrollController});

  @override
  State<ArtistShowdownHistorySheet> createState() =>
      _ArtistShowdownHistorySheetState();
}

class _ArtistShowdownHistorySheetState
    extends State<ArtistShowdownHistorySheet> {
  _UserFilter _userFilter = _UserFilter.both;
  String? _selectedTrack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ArtistShowdownProvider>();
      if (!provider.hasHistory && !provider.isLoadingHistory) {
        provider.loadArtistHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ArtistShowdownProvider>(
      builder: (context, showdown, _) {
        final artist = showdown.artist;
        final khentScrobbles = showdown.khentHistory;
        final clairScrobbles = showdown.clairHistory;

        // Combine scrobbles based on filter
        final combined = <_ScrobbleItem>[];
        if (_userFilter == _UserFilter.both || _userFilter == _UserFilter.khent) {
          for (final s in khentScrobbles) {
            combined.add(_ScrobbleItem(scrobble: s, isKhent: true));
          }
        }
        if (_userFilter == _UserFilter.both || _userFilter == _UserFilter.clair) {
          for (final s in clairScrobbles) {
            combined.add(_ScrobbleItem(scrobble: s, isKhent: false));
          }
        }

        // Apply track filter if chosen
        final filtered = _selectedTrack == null
            ? combined
            : combined
                .where((item) =>
                    item.scrobble.trackName.trim().toLowerCase() ==
                    _selectedTrack!.trim().toLowerCase())
                .toList();

        // Sort newest first
        filtered.sort((a, b) {
          final aTs = a.scrobble.timestamp?.millisecondsSinceEpoch ?? 0;
          final bTs = b.scrobble.timestamp?.millisecondsSinceEpoch ?? 0;
          return bTs.compareTo(aTs);
        });

        // Group by day key (YYYY-MM-DD)
        final groupedByDay = <String, List<_ScrobbleItem>>{};
        for (final item in filtered) {
          final date = item.scrobble.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dayKey = DateFormat('yyyy-MM-dd').format(date);
          groupedByDay.putIfAbsent(dayKey, () => []).add(item);
        }

        // Unique track names across all loaded history for the track filter chips
        final allTracks = <String>{};
        for (final s in [...khentScrobbles, ...clairScrobbles]) {
          if (s.trackName.trim().isNotEmpty) {
            allTracks.add(s.trackName.trim());
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.inkDeep,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.velvet.withValues(alpha: 0.98),
                AppColors.inkDeep,
              ],
            ),
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(
                artist: artist,
                isLoading: showdown.isLoadingHistory,
                onRefresh: () => showdown.loadArtistHistory(forceRefresh: true),
                onClose: () => Navigator.of(context).pop(),
              ),
              _FilterBar(
                userFilter: _userFilter,
                khentCount: khentScrobbles.length,
                clairCount: clairScrobbles.length,
                totalCount: khentScrobbles.length + clairScrobbles.length,
                onSelectUser: (f) => setState(() => _userFilter = f),
              ),
              if (allTracks.length > 1) ...[
                const SizedBox(height: 6),
                _TrackFilterChips(
                  tracks: allTracks.toList(),
                  selectedTrack: _selectedTrack,
                  onSelectTrack: (t) => setState(() => _selectedTrack = t),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: showdown.isLoadingHistory && !showdown.hasHistory
                    ? const _TimelineSkeleton()
                    : filtered.isEmpty
                        ? _EmptyHistory(
                            artist: artist,
                            userFilter: _userFilter,
                            selectedTrack: _selectedTrack,
                          )
                        : ListView.builder(
                            controller: widget.scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: groupedByDay.keys.length,
                            itemBuilder: (context, index) {
                              final dayKey = groupedByDay.keys.elementAt(index);
                              final dayItems = groupedByDay[dayKey]!;
                              final firstDate = dayItems.first.scrobble.timestamp;
                              return _DayGroup(
                                date: firstDate,
                                items: dayItems,
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScrobbleItem {
  final MusicStatus scrobble;
  final bool isKhent;
  const _ScrobbleItem({required this.scrobble, required this.isKhent});
}

class _SheetHeader extends StatelessWidget {
  final String artist;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.artist,
    required this.isLoading,
    required this.onRefresh,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top drag handle indicator
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.petalWhite.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 12, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.cinemaPink, AppColors.auroraLilac],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.16),
                  ),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: AppColors.petalWhite,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LISTENING TIMELINE',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: AppColors.blushGold,
                      ),
                    ),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.petalWhite,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.blushGold,
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Refresh history',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: AppColors.blushGold,
                  ),
                  onPressed: onRefresh,
                ),
              IconButton(
                tooltip: 'Close',
                icon: Icon(
                  Icons.close_rounded,
                  size: 22,
                  color: AppColors.textMuted,
                ),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          color: AppColors.petalWhite.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _UserFilter userFilter;
  final int khentCount;
  final int clairCount;
  final int totalCount;
  final ValueChanged<_UserFilter> onSelectUser;

  const _FilterBar({
    required this.userFilter,
    required this.khentCount,
    required this.clairCount,
    required this.totalCount,
    required this.onSelectUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.petalWhite.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.petalWhite.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _UserFilterPill(
                label: 'Both',
                count: totalCount,
                selected: userFilter == _UserFilter.both,
                activeColor: AppColors.blushGold,
                onTap: () => onSelectUser(_UserFilter.both),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _UserFilterPill(
                label: 'Khent',
                count: khentCount,
                selected: userFilter == _UserFilter.khent,
                activeColor: AppColors.auroraTeal,
                onTap: () => onSelectUser(_UserFilter.khent),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _UserFilterPill(
                label: 'Clair',
                count: clairCount,
                selected: userFilter == _UserFilter.clair,
                activeColor: AppColors.cinemaPink,
                onTap: () => onSelectUser(_UserFilter.clair),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserFilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _UserFilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 12,
                color: selected ? activeColor : AppColors.textMedium,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: 0.3)
                      : AppColors.petalWhite.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 10,
                    color: selected ? AppColors.petalWhite : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackFilterChips extends StatelessWidget {
  final List<String> tracks;
  final String? selectedTrack;
  final ValueChanged<String?> onSelectTrack;

  const _TrackFilterChips({
    required this.tracks,
    required this.selectedTrack,
    required this.onSelectTrack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _TrackChip(
            label: 'All Songs',
            selected: selectedTrack == null,
            onTap: () => onSelectTrack(null),
          ),
          const SizedBox(width: 8),
          for (final t in tracks) ...[
            _TrackChip(
              label: t,
              selected: selectedTrack == t,
              onTap: () => onSelectTrack(selectedTrack == t ? null : t),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TrackChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TrackChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: selected
              ? AppColors.blushGold.withValues(alpha: 0.16)
              : AppColors.petalWhite.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? AppColors.blushGold.withValues(alpha: 0.45)
                : AppColors.petalWhite.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitMedium.copyWith(
            fontSize: 11,
            color: selected ? AppColors.blushGold : AppColors.textMedium,
          ),
        ),
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  final DateTime? date;
  final List<_ScrobbleItem> items;

  const _DayGroup({required this.date, required this.items});

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDayHeader(date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10, top: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: AppColors.blushGold,
                ),
                const SizedBox(width: 6),
                Text(
                  dateLabel.toUpperCase(),
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    color: AppColors.blushGold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${items.length} ${items.length == 1 ? 'play' : 'plays'}',
                  style: AppTypography.outfitMedium.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            _TimelineRow(
              item: items[i],
              isFirst: i == 0,
              isLast: i == items.length - 1,
            ),
            if (i != items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  static String _formatDayHeader(DateTime? date) {
    if (date == null || date.millisecondsSinceEpoch == 0) return 'Undated';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(thatDay).inDays;
    if (diff == 0) return 'Today • ${DateFormat('MMM d, yyyy').format(date)}';
    if (diff == 1) return 'Yesterday • ${DateFormat('MMM d, yyyy').format(date)}';
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }
}

class _TimelineRow extends StatelessWidget {
  final _ScrobbleItem item;
  final bool isFirst;
  final bool isLast;

  const _TimelineRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final s = item.scrobble;
    final isKhent = item.isKhent;
    final userColor = isKhent ? AppColors.auroraTeal : AppColors.cinemaPink;
    final userName = isKhent ? 'KHENT' : 'CLAIR';
    final art = cleanLastfmImageUrl(s.imageUrl);
    final timeStr = s.timestamp != null
        ? DateFormat('h:mm a').format(s.timestamp!)
        : '—';

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => ListenAlongPopup(status: s),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.petalWhite.withValues(alpha: 0.04),
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: userColor.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            // User dot + time column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: userColor,
                        boxShadow: [
                          BoxShadow(
                            color: userColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      userName,
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 9,
                        letterSpacing: 1.0,
                        color: userColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  timeStr,
                  style: AppTypography.outfitMedium.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Track artwork
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: AppRadius.radiusMd,
                color: AppColors.velvet,
                border: Border.all(
                  color: AppColors.petalWhite.withValues(alpha: 0.08),
                ),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.radiusMd,
                child: art == null
                    ? const Icon(
                        Icons.music_note_rounded,
                        size: 18,
                        color: AppColors.roseQuartz,
                      )
                    : AppNetworkImage(
                        imageUrl: art,
                        fit: BoxFit.cover,
                        cacheWidth: 132,
                        errorWidget: const Icon(
                          Icons.music_note_rounded,
                          size: 18,
                          color: AppColors.roseQuartz,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Track title & album
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.trackName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.albumName.isNotEmpty
                        ? s.albumName
                        : s.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 11,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.play_circle_outline_rounded,
              size: 20,
              color: AppColors.blushGold,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final String artist;
  final _UserFilter userFilter;
  final String? selectedTrack;

  const _EmptyHistory({
    required this.artist,
    required this.userFilter,
    required this.selectedTrack,
  });

  @override
  Widget build(BuildContext context) {
    final userLabel = switch (userFilter) {
      _UserFilter.khent => "Khent hasn't",
      _UserFilter.clair => "Clair hasn't",
      _UserFilter.both => "Neither Khent nor Clair have",
    };

    final trackDesc = selectedTrack != null ? ' for "$selectedTrack"' : '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.petalWhite.withValues(alpha: 0.05),
                border: Border.all(
                  color: AppColors.petalWhite.withValues(alpha: 0.10),
                ),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 26,
                color: AppColors.roseQuartz,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No history found$trackDesc',
              textAlign: TextAlign.center,
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 15,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$userLabel scrobbled $artist yet, or timestamps have not synced.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitMedium.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        EverglowSkeleton(width: 140, height: 14, radius: 6),
        SizedBox(height: 12),
        EverglowSkeleton(height: 64, radius: 12),
        SizedBox(height: 10),
        EverglowSkeleton(height: 64, radius: 12),
        SizedBox(height: 20),
        EverglowSkeleton(width: 120, height: 14, radius: 6),
        SizedBox(height: 12),
        EverglowSkeleton(height: 64, radius: 12),
      ],
    );
  }
}
