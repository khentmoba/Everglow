part of 'katana_reader_screen.dart';

/// End card + top/bottom chrome for [_KatanaReaderScreenState].
extension _KatanaReaderChrome on _KatanaReaderScreenState {
  // ── End of Chapter Card ───────────────────────────────────────────
  Widget _buildEndCard() {
    final next = _nextChapter;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KatanaColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: KatanaColors.accent,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chapter Completed',
            style: KatanaType.small.copyWith(
              color: KatanaColors.accent,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _chapter.displayTitle,
            style: AppTypography.outfitBold.copyWith(
              color: KatanaColors.text,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (next != null) ...[
            Text('Up Next: ${next.displayTitle}', style: KatanaType.small),
            const SizedBox(height: 12),
            KatanaButton(
              label: 'Read Next Chapter',
              icon: Icons.arrow_forward_rounded,
              onTap: () => _goToChapter(next),
            ),
          ] else
            Column(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: KatanaColors.green,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  'You have caught up with the latest chapter!',
                  style: KatanaType.body.copyWith(
                    color: KatanaColors.textMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopChrome() {
    final dimActive = _brightness < 0.99;
    return Container(
      decoration: BoxDecoration(
        color: _themeStyle.surfaceColor.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: KatanaColors.borderStrong, width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _saveProgress(_currentPage);
                  navigator.pop();
                },
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: KatanaColors.accentSoft,
                ),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.mangaTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        color: KatanaColors.text,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      _chapter.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KatanaType.small.copyWith(
                        color: KatanaColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  _refresh(() {
                    if (_brightness < 0.95) {
                      _brightness = 1.0;
                    } else {
                      _brightness = 0.72;
                    }
                  });
                  _savePreferences();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: dimActive
                        ? KatanaColors.accent.withValues(alpha: 0.18)
                        : KatanaColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: dimActive
                          ? KatanaColors.accent
                          : KatanaColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dimActive
                            ? Icons.nights_stay_rounded
                            : Icons.wb_twilight_rounded,
                        size: 14,
                        color: dimActive
                            ? KatanaColors.accent
                            : KatanaColors.accentSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dimActive
                            ? '${(_brightness * 100).round()}%'
                            : 'Dimmer',
                        style: AppTypography.outfitBold.copyWith(
                          color: dimActive
                              ? KatanaColors.accent
                              : KatanaColors.accentSoft,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _bookmarked
                      ? KatanaColors.accent
                      : KatanaColors.textMuted,
                  size: 21,
                ),
                tooltip: _bookmarked ? 'Bookmarked' : 'Bookmark chapter',
                onPressed: _toggleBookmark,
              ),
              IconButton(
                icon: const Icon(
                  Icons.warning_amber_rounded,
                  color: KatanaColors.textLight,
                  size: 19,
                ),
                tooltip: 'Report error',
                onPressed: _reportChapter,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// MangaKatana-style quick toolbar: image server switch, Fit
  /// height toggle and Darken slider, right under the chapter nav
  /// like the site's reader options row.
  Widget _buildReaderToolbar() {
    final darken = ((1.0 - _brightness) * 100).clamp(0.0, 80.0);
    final paged = _mode != ReaderMode.webtoon;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Text('Server', style: KatanaType.small.copyWith(fontSize: 11)),
          const SizedBox(width: 6),
          _serverPill('1', ''),
          const SizedBox(width: 4),
          _serverPill('2', '?sv=mk'),
          const SizedBox(width: 4),
          _serverPill('3', '?sv=3'),
          const SizedBox(width: 10),
          Container(width: 1, height: 18, color: KatanaColors.border),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: paged
                ? () {
                    _refresh(() => _fitHeight = !_fitHeight);
                    _savePreferences();
                  }
                : null,
            child: Opacity(
              opacity: paged ? 1.0 : 0.45,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _fitHeight && paged
                      ? KatanaColors.accent.withValues(alpha: 0.16)
                      : KatanaColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _fitHeight && paged
                        ? KatanaColors.accent
                        : KatanaColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _fitHeight
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 14,
                      color: _fitHeight && paged
                          ? KatanaColors.accent
                          : KatanaColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Fit height',
                      style: AppTypography.outfitBold.copyWith(
                        color: _fitHeight && paged
                            ? KatanaColors.accent
                            : KatanaColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 18, color: KatanaColors.border),
          const SizedBox(width: 10),
          Text('Darken', style: KatanaType.small.copyWith(fontSize: 11)),
          SizedBox(
            width: 110,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: darken,
                min: 0,
                max: 80,
                divisions: 16,
                activeColor: KatanaColors.accent,
                inactiveColor: KatanaColors.border,
                onChanged: _setDarken,
              ),
            ),
          ),
          Text(
            '${darken.round()}%',
            style: KatanaType.small.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverPill(String label, String value) {
    final selected = _server == value;
    return GestureDetector(
      onTap: () => _changeServer(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? KatanaColors.accent.withValues(alpha: 0.16)
              : KatanaColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? KatanaColors.accent : KatanaColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitBold.copyWith(
            color: selected ? KatanaColors.accent : KatanaColors.textMuted,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomChrome() {
    return Container(
      decoration: BoxDecoration(
        color: _themeStyle.surfaceColor.withValues(alpha: 0.96),
        border: const Border(
          top: BorderSide(color: KatanaColors.borderStrong, width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrubber Row
              if (_pages.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: KatanaColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: KatanaColors.accent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        '$_currentPage',
                        style: AppTypography.outfitBold.copyWith(
                          color: KatanaColors.accent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: _currentPage.toDouble().clamp(
                            1.0,
                            math.max(1.0, _pages.length.toDouble()),
                          ),
                          min: 1.0,
                          max: math.max(1.0, _pages.length.toDouble()),
                          divisions: math.max(1, _pages.length - 1),
                          activeColor: KatanaColors.accent,
                          inactiveColor: KatanaColors.border,
                          onChanged: (v) {
                            _jumpToPage(v.round());
                          },
                        ),
                      ),
                    ),
                    Text(
                      '${_pages.length}',
                      style: KatanaType.small.copyWith(
                        color: KatanaColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              _buildReaderToolbar(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _navButton(
                      label: '‹ Prev',
                      enabled: _prevChapter != null,
                      onTap: _prevChapter != null
                          ? () => _goToChapter(_prevChapter!)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _openChapterPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: KatanaColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: KatanaColors.borderStrong),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 15,
                              color: KatanaColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _chapter.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitBold.copyWith(
                                  color: KatanaColors.text,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: KatanaColors.accentSoft,
                              size: 17,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Reader settings',
                    child: GestureDetector(
                      onTap: _openSettings,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 11,
                        ),
                        decoration: BoxDecoration(
                          color: KatanaColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: KatanaColors.border),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: KatanaColors.accentSoft,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _navButton(
                      label: 'Next ›',
                      enabled: _nextChapter != null,
                      primary: true,
                      onTap: _nextChapter != null
                          ? () => _goToChapter(_nextChapter!)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton({
    required String label,
    required bool enabled,
    required VoidCallback? onTap,
    bool primary = false,
  }) {
    final highlightPink = primary && enabled;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: highlightPink
              ? const LinearGradient(
                  colors: [KatanaColors.accent, KatanaColors.accentDark],
                )
              : null,
          color: highlightPink
              ? null
              : (enabled ? KatanaColors.surfaceAlt : KatanaColors.surface),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: highlightPink
                ? KatanaColors.accentSoft
                : KatanaColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.outfitBold.copyWith(
            color: highlightPink
                ? Colors.white
                : (enabled ? KatanaColors.text : KatanaColors.textLight),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
