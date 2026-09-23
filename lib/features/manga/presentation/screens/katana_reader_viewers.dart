part of 'katana_reader_screen.dart';

/// Page viewer builders + page recovery for [_KatanaReaderScreenState].
extension _KatanaReaderViewers on _KatanaReaderScreenState {
  Widget _buildReaderBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: KatanaColors.accent),
            const SizedBox(height: 16),
            Text(
              'Loading ${_chapter.displayTitle}...',
              style: AppTypography.outfitBold.copyWith(
                color: KatanaColors.text,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching pages from the source — this can take a few seconds.',
              style: KatanaType.small.copyWith(
                color: KatanaColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_rounded,
                size: 46,
                color: KatanaColors.textLight,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: KatanaType.body,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KatanaButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onTap: _loadPages,
                  ),
                  const SizedBox(width: 10),
                  KatanaButton(
                    label: 'Settings',
                    icon: Icons.tune_rounded,
                    onTap: _openSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_mode == ReaderMode.webtoon) {
      return _buildWebtoonViewer();
    } else {
      return _buildPagedViewer();
    }
  }

  // ── Webtoon Continuous Mode ───────────────────────────────────────
  Widget _buildWebtoonViewer() {
    final width = MediaQuery.sizeOf(context).width;
    final maxContentWidth = width > 850 ? 850.0 : double.infinity;
    final desktopWeb = KatanaReaderScreen.isDesktopWeb(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          physics: desktopWeb
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          // Keep neighbours built so paging back and forth never
          // re-resolves an image that already loaded.
          scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemCount: _pages.length + 1,
          itemBuilder: (context, index) {
            if (index == _pages.length) return _buildEndCard();
            return _buildWebtoonImage(index);
          },
        ),
      ),
    );

    final desktopContent = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (event) {
        scrollReaderWithWheel(event, _scrollController);
      },
      child: content,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleChrome,
      onDoubleTap: _handleDoubleTap,
      // InteractiveViewer maps upward mouse-wheel notches to zoom on
      // desktop web. Omit it there and forward wheel events explicitly;
      // touch/mobile web and native builds retain pinch/double-tap zoom.
      child: desktopWeb
          ? desktopContent
          : InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 3.5,
              child: content,
            ),
    );
  }

  Widget _buildWebtoonImage(int index) {
    return _readerPage(index, fit: BoxFit.fitWidth, height: null);
  }

  // ── Paged Mode (RTL for Manga, LTR for Western) ───────────────────
  Widget _buildPagedViewer() {
    final isRTL = _mode == ReaderMode.pagedRTL;
    final width = MediaQuery.sizeOf(context).width;
    final useTwoPage = _twoPage && width >= 840;

    final totalItems = useTwoPage
        ? (_pages.length / 2).ceil() + 1
        : _pages.length + 1;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final dx = details.localPosition.dx;

        // Left 28% edge
        if (dx < screenWidth * 0.28) {
          if (isRTL) {
            _advancePaged(1);
          } else {
            _advancePaged(-1);
          }
        }
        // Right 28% edge
        else if (dx > screenWidth * 0.72) {
          if (isRTL) {
            _advancePaged(-1);
          } else {
            _advancePaged(1);
          }
        }
        // Center 44% zone: toggle chrome
        else {
          _toggleChrome();
        }
      },
      child: PageView.builder(
        controller: _pageController,
        reverse: isRTL,
        physics: const BouncingScrollPhysics(),
        itemCount: totalItems,
        onPageChanged: (pageIndex) {
          if (useTwoPage) {
            final firstPageIndex = pageIndex * 2;
            _onPageChanged(math.min(firstPageIndex, _pages.length - 1));
          } else {
            if (pageIndex < _pages.length) {
              _onPageChanged(pageIndex);
            }
          }
        },
        itemBuilder: (context, index) {
          if (useTwoPage) {
            final pageA = index * 2;
            final pageB = pageA + 1;
            if (pageA >= _pages.length) return _buildEndCard();

            return InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.5,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSinglePagedImage(
                      isRTL ? (pageB < _pages.length ? pageB : pageA) : pageA,
                    ),
                  ),
                  if (pageB < _pages.length)
                    Expanded(
                      child: _buildSinglePagedImage(isRTL ? pageA : pageB),
                    ),
                ],
              ),
            );
          }

          if (index == _pages.length) return _buildEndCard();

          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 3.5,
            child: Center(child: _buildSinglePagedImage(index)),
          );
        },
      ),
    );
  }

  Widget _buildSinglePagedImage(int index) {
    // Fit height ON resizes the page into the viewport (the site's
    // default); OFF shows it full-width with vertical scroll.
    if (!_fitHeight) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: _readerPage(index, fit: BoxFit.fitWidth),
      );
    }
    return _readerPage(index, fit: BoxFit.contain, height: double.infinity);
  }

  /// One page image with persistent cache and per-page retries.
  /// Keyed by the CDN-host step so a silent host switch remounts
  /// the image for the new URL with a fresh retry budget.
  Widget _readerPage(int index, {required BoxFit fit, double? height}) {
    return ReaderPageImage(
      key: ValueKey('p$index-s${_cdnStep[index] ?? 0}'),
      imageUrl: _proxiedPageUrl(index),
      pageNumber: index + 1,
      fit: fit,
      height: height,
      slotColor: _themeStyle.surfaceColor,
      accentColor: KatanaColors.accent,
      mutedColor: KatanaColors.textMuted,
      onError: () => _onReaderPageError(index),
      secondaryAction: KatanaButton(
        label: 'Try another server',
        icon: Icons.dns_rounded,
        onTap: _cycleServer,
      ),
    );
  }

  void _advancePaged(int delta) {
    if (!_pageController.hasClients) return;
    final current = _pageController.page?.round() ?? 0;
    final target = current + delta;
    if (target >= 0 && target <= _pages.length) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Proxied URL for page [index], including whatever CDN-host
  /// fallback step the page has silently advanced to after failures.
  String _proxiedPageUrl(int index) {
    final origin = KatanaService.cdnFallbackUrl(
      _pages[index],
      _cdnStep[index] ?? 0,
    );
    return _service.proxiedImageUrl(origin);
  }

  /// Failure hook for page [index], called by [ReaderPageImage].
  /// Like the site's reader, a failed image first retries silently
  /// on the other CDN hosts; only when every host fails is the page
  /// recorded for the token-URL refresh. The visible loading and
  /// tap-to-retry slots live in [ReaderPageImage] itself, so a slow
  /// or broken page never shows as a black gap.
  void _onReaderPageError(int index) {
    final origin = index < _pages.length ? _pages[index] : '';
    if (origin.isEmpty) return;
    final step = _cdnStep[index] ?? 0;
    if (step < KatanaService.cdnFallbackCount(origin)) {
      final key = '$index:$step';
      if (_fallbackScheduled.add(key)) {
        final chapterId = _chapter.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fallbackScheduled.remove(key);
          if (!mounted || index >= _pages.length) return;
          if (_chapter.id != chapterId) return;
          _refresh(() => _cdnStep[index] = step + 1);
        });
      }
      return;
    }
    _notePageFailed(index);
  }

  /// Records a page whose every CDN host failed. When several pages
  /// fail together the chapter's token URLs have usually expired, so
  /// — like the site's own refresh — the URLs are fetched fresh once
  /// instead of leaving Clair with a broken chapter.
  void _notePageFailed(int index) {
    if (!_failedPages.add(index)) return;
    _maybeRefreshTokens();
  }

  Future<void> _maybeRefreshTokens() async {
    if (_tokenRefreshed || _refreshingTokens || _failedPages.length < 3) {
      return;
    }
    _refreshingTokens = true;
    final fresh = await _service.fetchChapterPages(
      widget.slug,
      _chapter.path,
      server: _server,
    );
    _refreshingTokens = false;
    if (!mounted) return;
    // Only swap when the fresh list matches page-for-page, exactly
    // like the site, which refuses to remap a mismatched refresh.
    if (fresh.isEmpty || fresh.length != _pages.length) return;
    _tokenRefreshed = true;
    _refresh(() {
      _pages = fresh;
      _cdnStep.clear();
      _failedPages.clear();
    });
    _showSnack('Page links refreshed — retry the failed pages.');
  }

  /// Cycles Server 1 → 2 → 3 → 1, like the site's "Click another
  /// server if the images is not displayed" switch.
  void _cycleServer() {
    const order = ['', '?sv=mk', '?sv=3'];
    const labels = ['Server 1', 'Server 2', 'Server 3'];
    final next = order[(order.indexOf(_server) + 1) % order.length];
    _refresh(() => _server = next);
    _showSnack('Switched to ${labels[order.indexOf(next)]}');
    _loadPages();
  }
}
