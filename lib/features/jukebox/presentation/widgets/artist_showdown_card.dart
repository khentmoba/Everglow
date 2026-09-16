import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';
import '../../data/models/lastfm_image_utils.dart';
import '../../data/models/music_status.dart';
import '../providers/artist_showdown_provider.dart';
import '../providers/music_stats_provider.dart';
import 'listen_along_popup.dart';

/// Khent vs Clair for any artist: a head-to-head total plus the song-by-song
/// table. Opens on Ethel Cain; the search box and quick picks switch artists.
class ArtistShowdownCard extends StatefulWidget {
  const ArtistShowdownCard({super.key});

  @override
  State<ArtistShowdownCard> createState() => _ArtistShowdownCardState();
}

class _ArtistShowdownCardState extends State<ArtistShowdownCard> {
  late final TextEditingController _search;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ArtistShowdownProvider, MusicStatsProvider>(
      builder: (context, showdown, stats, _) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusX2,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.velvet.withValues(alpha: 0.92),
                AppColors.inkDeep.withValues(alpha: 0.96),
              ],
            ),
            border: Border.all(
              color: AppColors.moonlight.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(artist: showdown.artist),
              const SizedBox(height: AppSpacing.lg),
              _ArtistSearch(
                controller: _search,
                onSubmit: (value) {
                  showdown.selectArtist(value);
                  _search.clear();
                  FocusScope.of(context).unfocus();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _QuickPicks(
                artists: _suggestions(stats),
                selected: showdown.artist,
                onPick: showdown.selectArtist,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (showdown.isLoading && !showdown.hasData)
                const _ShowdownSkeleton()
              else if (!showdown.hasData)
                _EmptyShowdown(artist: showdown.artist)
              else ...[
                if (showdown.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: EverglowSkeleton(
                      width: double.infinity,
                      height: 4,
                      radius: 99,
                    ),
                  ),
                _VersusTotal(showdown: showdown),
                const SizedBox(height: AppSpacing.lg),
                _SongTable(
                  showdown: showdown,
                  expanded: _expanded,
                  onToggleExpand: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Quick picks: Ethel Cain first, then the unique artists from both
  /// Top 10s (already loaded — zero extra calls).
  List<String> _suggestions(MusicStatsProvider stats) {
    final seen = <String>{};
    final picks = <String>[ArtistShowdownProvider.defaultArtist];
    seen.add(ArtistShowdownProvider.defaultArtist.toLowerCase());
    for (final track in [...stats.topTracks, ...stats.clairTopTracks]) {
      final key = track.artistName.trim().toLowerCase();
      if (key.isEmpty || key == 'unknown artist' || !seen.add(key)) {
        continue;
      }
      picks.add(track.artistName.trim());
    }
    return picks;
  }
}

class _Header extends StatelessWidget {
  final String artist;
  const _Header({required this.artist});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.cinemaPink, AppColors.auroraLilac],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.leaderboard_rounded,
            size: 18,
            color: AppColors.petalWhite,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ARTIST SHOWDOWN',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  color: AppColors.blushGold,
                ),
              ),
              Text(
                '$artist • Khent vs Clair',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitMedium.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtistSearch extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  const _ArtistSearch({required this.controller, required this.onSubmit});

  @override
  State<_ArtistSearch> createState() => _ArtistSearchState();
}

class _ArtistSearchState extends State<_ArtistSearch> {
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _query = value;
    _debounce?.cancel();
    final showdown = context.read<ArtistShowdownProvider>();
    if (value.trim().length < 2) {
      showdown.clearSuggestions();
      setState(() {});
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      showdown.searchArtists(value);
    });
  }

  void _pick(String name) {
    _debounce?.cancel();
    _query = '';
    widget.onSubmit(name);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ArtistShowdownProvider>(
      builder: (context, showdown, _) {
        final showDropdown =
            _query.trim().length >= 2 &&
            (showdown.isSearching || showdown.suggestions.isNotEmpty);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: widget.controller,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _pick,
              style: AppTypography.outfitMedium.copyWith(
                fontSize: 13,
                color: AppColors.petalWhite,
              ),
              decoration: InputDecoration(
                hintText: 'Pick an artist… try Lana Del Rey',
                hintStyle: AppTypography.outfitMedium.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.roseQuartz,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.blushGold,
                  ),
                  onPressed: () => _pick(widget.controller.text),
                ),
                filled: true,
                fillColor: AppColors.petalWhite.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.petalWhite.withValues(alpha: 0.10),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.petalWhite.withValues(alpha: 0.10),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.blushGold.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            if (showDropdown) ...[
              const SizedBox(height: 8),
              _SuggestionDropdown(
                showdown: showdown,
                onPick: _pick,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Autocomplete dropdown under the search box: tap a name to load its
/// showdown. Solid fill (no blur) and a capped height so it stays cheap
/// on web and never pushes the card into an unbounded list.
class _SuggestionDropdown extends StatelessWidget {
  final ArtistShowdownProvider showdown;
  final ValueChanged<String> onPick;
  const _SuggestionDropdown({required this.showdown, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.inkDeep,
        border: Border.all(
          color: AppColors.petalWhite.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkDeep.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: showdown.isSearching && showdown.suggestions.isEmpty
            ? const _SearchingRow()
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: showdown.suggestions.length,
                separatorBuilder: (_, _) => Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: AppColors.petalWhite.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, i) {
                  final s = showdown.suggestions[i];
                  return _SuggestionRow(
                    name: s.name,
                    listeners: s.listeners,
                    imageUrl: s.imageUrl,
                    onTap: () => onPick(s.name),
                  );
                },
              ),
      ),
    );
  }
}

class _SearchingRow extends StatelessWidget {
  const _SearchingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Searching artists…',
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final String name;
  final int listeners;
  final String? imageUrl;
  final VoidCallback onTap;
  const _SuggestionRow({
    required this.name,
    required this.listeners,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final art = imageUrl;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
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
                    ? _ArtistInitial(name: name)
                    : AppNetworkImage(
                        imageUrl: art,
                        fit: BoxFit.cover,
                        cacheWidth: 72,
                        errorWidget: _ArtistInitial(name: name),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 13,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    listeners > 0
                        ? '${_formatListeners(listeners)} listeners'
                        : 'Tap to compare',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitMedium.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.north_west_rounded,
              size: 16,
              color: AppColors.blushGold,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatListeners(int value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}K';
    }
    return '$value';
  }
}

/// Initial tile shown while an artist photo loads (or when Spotify has
/// none). A big letter on the house gradient reads as intentional, where
/// the old tiny person glyph looked like a broken image.
class _ArtistInitial extends StatelessWidget {
  final String name;
  const _ArtistInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cinemaPink, AppColors.auroraLilac],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initial,
        style: AppTypography.outfitBold.copyWith(
          fontSize: 16,
          color: AppColors.petalWhite,
        ),
      ),
    );
  }
}

class _QuickPicks extends StatelessWidget {
  final List<String> artists;
  final String selected;
  final ValueChanged<String> onPick;
  const _QuickPicks({
    required this.artists,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < artists.length; i++) ...[
            _PickChip(
              label: artists[i],
              selected:
                  artists[i].toLowerCase() == selected.trim().toLowerCase(),
              onTap: () => onPick(artists[i]),
            ),
            if (i != artists.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: selected
              ? AppColors.blushGold.withValues(alpha: 0.16)
              : AppColors.petalWhite.withValues(alpha: 0.05),
          border: Border.all(
            color: selected
                ? AppColors.blushGold.withValues(alpha: 0.45)
                : AppColors.petalWhite.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitBold.copyWith(
            fontSize: 11,
            color: selected ? AppColors.blushGold : AppColors.textMedium,
          ),
        ),
      ),
    );
  }
}

class _VersusTotal extends StatelessWidget {
  final ArtistShowdownProvider showdown;
  const _VersusTotal({required this.showdown});

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.decimalPattern();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ScoreBlock(
                name: 'Khent',
                plays: showdown.khentTotal,
                formatted: format.format(showdown.khentTotal),
                color: AppColors.auroraTeal,
                isLeader: showdown.leader == 'khent',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'VS',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: _ScoreBlock(
                name: 'Clair',
                plays: showdown.clairTotal,
                formatted: format.format(showdown.clairTotal),
                color: AppColors.cinemaPink,
                isLeader: showdown.leader == 'clair',
                alignEnd: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: (showdown.khentShare * 1000).round().clamp(1, 999),
                  child: Container(color: AppColors.auroraTeal),
                ),
                Expanded(
                  flex:
                      ((1 - showdown.khentShare) * 1000).round().clamp(1, 999),
                  child: Container(
                    color: AppColors.cinemaPink.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  final String name;
  final int plays;
  final String formatted;
  final Color color;
  final bool isLeader;
  final bool alignEnd;
  const _ScoreBlock({
    required this.name,
    required this.plays,
    required this.formatted,
    required this.color,
    required this.isLeader,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: isLeader ? 0.14 : 0.06),
        border: Border.all(
          color: color.withValues(alpha: isLeader ? 0.45 : 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLeader && !alignEnd) ...[
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 14,
                  color: AppColors.auroraGold,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: color,
                  ),
                ),
              ),
              if (isLeader && alignEnd) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 14,
                  color: AppColors.auroraGold,
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            formatted,
            style: AppTypography.cormorantHeading.copyWith(
              fontSize: 26,
              height: 1.0,
              color: AppColors.petalWhite,
            ),
          ),
          Text(
            plays == 1 ? 'play' : 'plays',
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 10,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SongTable extends StatelessWidget {
  final ArtistShowdownProvider showdown;
  final bool expanded;
  final VoidCallback onToggleExpand;
  const _SongTable({
    required this.showdown,
    required this.expanded,
    required this.onToggleExpand,
  });

  static const int _collapsedCount = 10;

  @override
  Widget build(BuildContext context) {
    final tracks = showdown.tracks;
    final visible = expanded
        ? tracks
        : tracks.take(_collapsedCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SONG BY SONG',
          style: AppTypography.outfitBold.copyWith(
            fontSize: 10,
            letterSpacing: 1.8,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < visible.length; i++) ...[
          _SongRow(track: visible[i], rank: i + 1, artist: showdown.artist),
          if (i != visible.length - 1)
            Container(
              height: 1,
              color: AppColors.petalWhite.withValues(alpha: 0.06),
            ),
        ],
        if (tracks.length > _collapsedCount)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: onToggleExpand,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.petalWhite.withValues(alpha: 0.05),
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.08),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  expanded
                      ? 'Show less'
                      : 'Show all ${tracks.length} songs',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 12,
                    color: AppColors.blushGold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SongRow extends StatelessWidget {
  final ShowdownTrack track;
  final int rank;
  final String artist;
  const _SongRow({
    required this.track,
    required this.rank,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    final leaderColor = switch (track.leader) {
      'khent' => AppColors.auroraTeal,
      'clair' => AppColors.cinemaPink,
      _ => AppColors.textMuted,
    };
    // Last.fm sometimes ships its default star/disc placeholder instead of a
    // real cover — treat it as missing so the row falls back to the note.
    final art = cleanLastfmImageUrl(track.imageUrl);
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => ListenAlongPopup(
          status: MusicStatus(
            username: '',
            trackName: track.trackName,
            artistName: artist,
            albumName: '',
            imageUrl: art,
            isPlaying: false,
            spotifyUrl: track.spotifyUrl,
          ),
        ),
      ),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
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
                        size: 16,
                        color: AppColors.roseQuartz,
                      )
                    : AppNetworkImage(
                        imageUrl: art,
                        fit: BoxFit.cover,
                        cacheWidth: 120,
                        errorWidget: const Icon(
                          Icons.music_note_rounded,
                          size: 16,
                          color: AppColors.roseQuartz,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.trackName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 13,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _MiniCount(
                        label: 'Khent',
                        value: track.khentPlays,
                        color: AppColors.auroraTeal,
                        wins: track.leader == 'khent',
                      ),
                      const SizedBox(width: 8),
                      _MiniCount(
                        label: 'Clair',
                        value: track.clairPlays,
                        color: AppColors.cinemaPink,
                        wins: track.leader == 'clair',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: leaderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCount extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool wins;
  const _MiniCount({
    required this.label,
    required this.value,
    required this.color,
    required this.wins,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: AppTypography.outfitBold.copyWith(
              fontSize: 10,
              color: color.withValues(alpha: wins ? 1.0 : 0.55),
            ),
          ),
          TextSpan(
            text: NumberFormat.decimalPattern().format(value),
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 11,
              color: wins ? AppColors.petalWhite : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyShowdown extends StatelessWidget {
  final String artist;
  const _EmptyShowdown({required this.artist});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.petalWhite.withValues(alpha: 0.04),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.petalWhite.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.leaderboard_rounded,
            size: 22,
            color: AppColors.roseQuartz,
          ),
          const SizedBox(height: 8),
          Text(
            'No $artist plays yet',
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 12,
              color: AppColors.textMedium,
            ),
          ),
          Text(
            'Play one and take the lead.',
            style: AppTypography.outfitMedium.copyWith(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowdownSkeleton extends StatelessWidget {
  const _ShowdownSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: EverglowSkeleton(height: 86, radius: 14),
            ),
            SizedBox(width: 10),
            Expanded(
              child: EverglowSkeleton(height: 86, radius: 14),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        EverglowSkeleton(width: double.infinity, height: 13, radius: 6),
        SizedBox(height: 10),
        EverglowSkeleton(width: double.infinity, height: 13, radius: 6),
        SizedBox(height: 10),
        EverglowSkeleton(width: 200, height: 13, radius: 6),
      ],
    );
  }
}
