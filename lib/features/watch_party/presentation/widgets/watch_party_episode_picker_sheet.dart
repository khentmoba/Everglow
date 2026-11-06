import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

/// Season/episode picker shared by the title picker and the in-party
/// episode button. Picking here is how one of you moves the room to a new
/// episode; the other client follows on the next snapshot.
class WatchPartyEpisodePickerSheet extends StatefulWidget {
  final String title;
  final bool isAnime;
  final int initialSeason;
  final int initialEpisode;
  final int maxSeasons;
  final int maxEpisodes;
  final void Function(int season, int episode) onConfirm;

  const WatchPartyEpisodePickerSheet({
    super.key,
    required this.title,
    required this.isAnime,
    this.initialSeason = 1,
    this.initialEpisode = 1,
    this.maxSeasons = 20,
    this.maxEpisodes = 24,
    required this.onConfirm,
  });

  @override
  State<WatchPartyEpisodePickerSheet> createState() =>
      _WatchPartyEpisodePickerSheetState();
}

class _WatchPartyEpisodePickerSheetState
    extends State<WatchPartyEpisodePickerSheet> {
  late int _season;
  late int _episode;
  late final int _maxEpisodes;

  @override
  void initState() {
    super.initState();
    _season = widget.initialSeason.clamp(1, widget.maxSeasons);
    _maxEpisodes = widget.maxEpisodes.clamp(1, 2000);
    _episode = widget.initialEpisode.clamp(1, _maxEpisodes);
  }

  void _pickEpisode(int episode) {
    HapticFeedback.selectionClick();
    setState(() => _episode = episode);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = (mediaQuery.size.height * 0.86).clamp(380.0, 720.0);
    return Container(
      height: maxHeight,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.inkDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: AppColors.moonlight.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.petalWhite.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick an episode',
                      style: AppTypography.outfitHeading.copyWith(
                        color: AppColors.petalWhite,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitMuted.copyWith(
                        color: AppColors.mutedPurple,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.petalWhite,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!widget.isAnime) ...[
            _label('Season'),
            const SizedBox(height: 6),
            _stepper(
              value: _season,
              min: 1,
              max: widget.maxSeasons,
              onChanged: (v) => setState(() => _season = v),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(child: _label('Episode')),
              Text(
                'S$_season E$_episode',
                style: AppTypography.outfitHeading.copyWith(
                  color: AppColors.roseQuartz,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 58,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.35,
              ),
              itemCount: _maxEpisodes,
              itemBuilder: (context, index) {
                final number = index + 1;
                final active = number == _episode;
                return Semantics(
                  button: true,
                  selected: active,
                  label: 'Episode $number',
                  child: GestureDetector(
                    onTap: () => _pickEpisode(number),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.deepRose.withValues(alpha: 0.85)
                            : AppColors.shimmerBase,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(
                          color: active
                              ? AppColors.roseQuartz
                              : AppColors.moonlight.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        '$number',
                        style: AppTypography.outfitHeading.copyWith(
                          color: active
                              ? AppColors.petalWhite
                              : AppColors.textMedium,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onConfirm(_season, _episode);
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.auroraRose, AppColors.deepRose],
                ),
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isAnime
                          ? 'Watch episode $_episode'
                          : 'Watch S$_season E$_episode',
                      style: AppTypography.outfitHeading.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppTypography.outfitHeading.copyWith(
        color: AppColors.petalWhite,
        fontSize: 13,
      ),
    );
  }

  Widget _stepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: value > min
                ? AppColors.petalWhite
                : AppColors.petalWhite.withValues(alpha: 0.2),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Text(
            '$value',
            style: AppTypography.outfitHeading.copyWith(
              color: AppColors.petalWhite,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: value < max
                ? AppColors.petalWhite
                : AppColors.petalWhite.withValues(alpha: 0.2),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
