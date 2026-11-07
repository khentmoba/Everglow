part of 'watch_party_screen_web.dart';

abstract class _WatchPartyScreenStateCore2 extends _WatchPartyScreenStateCore {
  Future<void> _showMediaPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WatchPartyMediaPickerSheet(
        currentTitle: _room.title,
        initialCategory: _room.isAnime
            ? WatchPartyPickerCategory.anime
            : WatchPartyPickerCategory.cinema,
        onSelect: _applyMedia,
      ),
    );
  }

  Future<void> _applyMedia(MediaRef media) async {
    final roomId = _room.id;
    final uid = _myUid;
    await _service.updateMedia(
      roomId: roomId,
      mediaType: media.mediaType,
      tmdbId: media.tmdbId,
      malId: media.malId,
      isAnime: media.isAnime,
      season: media.season,
      episode: media.episode,
      episodeCount: media.episodeCount,
      title: media.title,
      posterPath: media.posterPath,
      updatedBy: uid,
    );
    if (!mounted) return;
    final wasHlsMounted = _isHlsMounted;
    setState(() {
      _room = _room
          .copyWithMedia(
            mediaType: media.mediaType,
            tmdbId: media.tmdbId,
            malId: media.malId,
            isAnime: media.isAnime,
            season: media.season,
            episode: media.episode,
            episodeCount: media.episodeCount,
            title: media.title,
            posterPath: media.posterPath,
            state: 'paused',
            currentTime: 0.0,
            positionAt: DateTime.now(),
          )
          .copyWithServer(
            serverType: 'everglow',
            serverName: 'Everglow',
            serverHost: 'everglow',
          )
          .copyWithCaptions(subtitleUrl: null, captionsOn: true);
      _hostExplicitlyPaused = true;
      _cinesrcReady = false;
      _hlsReady = false;
      _hlsFailed = false;
      _hlsError = null;
      _everglowStreamUrl = null;
      if (!(wasHlsMounted && _isHlsMounted)) {
        _regenerateHlsViewType();
      }
      _availableSubtitles = const [];
      _captionsOn = true;
    });
    unawaited(_resolveEverglowStream(startSeconds: 0));
  }

  /// Open the episode picker for the current series. Picking an episode
  /// writes it to the room, so the other client reloads the same episode
  /// without either side needing to tell the other.
  Future<void> _showEpisodePicker() async {
    if (!_room.isSeries) return;
    final maxEpisodes = _room.episodeCount ?? 100;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => WatchPartyEpisodePickerSheet(
        title: _room.title,
        isAnime: _room.isAnime,
        initialSeason: _room.season ?? 1,
        initialEpisode: _room.episode ?? 1,
        maxEpisodes: maxEpisodes,
        onConfirm: (season, episode) {
          Navigator.of(sheetContext).pop();
          unawaited(_applyEpisode(season, episode));
        },
      ),
    );
  }

  Future<void> _applyEpisode(int season, int episode) async {
    final roomId = _room.id;
    final uid = _myUid;
    await _service.updateEpisode(
      roomId: roomId,
      season: season,
      episode: episode,
      updatedBy: uid,
    );
    if (!mounted) return;
    final wasHlsMounted = _isHlsMounted;
    setState(() {
      _room = _room
          .copyWith(
            season: season,
            episode: episode,
            state: 'paused',
            currentTime: 0.0,
            positionAt: DateTime.now(),
          )
          .copyWithCaptions(subtitleUrl: null, captionsOn: true);
      _hostExplicitlyPaused = true;
      _hlsReady = false;
      _hlsFailed = false;
      _hlsError = null;
      _everglowStreamUrl = null;
      if (!(wasHlsMounted && _isHlsMounted)) {
        _regenerateHlsViewType();
      }
      _availableSubtitles = const [];
      _captionsOn = true;
    });
    if (_isEverglowServer) {
      unawaited(_resolveEverglowStream(startSeconds: 0));
    } else if (_isHlsServer) {
      _reloadHlsAt(0);
    } else if (_usesIframe) {
      if (_room.isAnime) {
        _bootstrapAnime();
      } else {
        _rebuildAt(0);
      }
    }
  }

  /// Caption picker for HLS rooms. The chosen track is written to the
  /// room, so turning captions on, off, or to another language happens
  /// on both screens at once.
  Future<void> _showCaptionPicker() async {
    if (!_isHlsServer) return;
    var tracks = _availableSubtitles;
    if (tracks.isEmpty && (_room.subtitleUrl ?? '').isNotEmpty) {
      tracks = [
        WatchPartySubtitle(url: _room.subtitleUrl!, label: 'Current track'),
      ];
    }
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No captions are available for this title.'),
        ),
      );
      return;
    }
    final chosen = _room.subtitleUrl ??
        (_captionsOn && tracks.isNotEmpty ? tracks.first.url : null);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CaptionPickerSheet(
        tracks: tracks,
        selectedUrl: chosen,
        captionsOn: _captionsOn,
        onSelect: (url) {
          Navigator.of(sheetContext).pop();
          unawaited(_applyCaptions(url));
        },
      ),
    );
  }

  Future<void> _applyCaptions(String? url) async {
    final on = url != null;
    await _service.updateCaptions(
      roomId: _room.id,
      subtitleUrl: url,
      captionsOn: on,
      updatedBy: _myUid,
    );
    if (!mounted) return;
    setState(() {
      _captionsOn = on;
      _room = _room.copyWithCaptions(subtitleUrl: url, captionsOn: on);
    });
    _hlsController.setCaptions(on);
  }

  Future<void> _showServerPicker() async {
    final serverService = WatchPartyServerService();
    final current = _isEverglowServer
        ? WatchPartyServer.everglow
        : _room.streamUrl == null
        ? null
        : WatchPartyServer.fromRoom(
            serverType: _room.serverType ?? 'embed',
            serverName: _room.serverName ?? 'Server',
            serverHost: _room.serverHost ?? 'custom',
            streamUrl: _room.streamUrl ?? '',
            subtitleUrl: _room.subtitleUrl,
            proxyEnabled: _room.proxyEnabled,
          );
    final servers = [
      WatchPartyServer.everglow,
      ...serverService.servers.where((s) => s.id != WatchPartyServer.everglow.id),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ServerPickerSheet(
        servers: servers,
        selected: current,
        onSelect: _applyServer,
      ),
    );
  }

  Future<void> _applyServer(WatchPartyServer? server) async {
    final roomId = _room.id;
    final uid = _myUid;
    if (server == null) {
      await _service.clearServer(roomId: roomId, updatedBy: uid);
      if (!mounted) return;
      final wasHlsMounted = _isHlsMounted;
      setState(() {
        _room = _room
            .copyWith(
              state: 'paused',
              currentTime: 0.0,
              positionAt: DateTime.now(),
            )
            .copyWithServer();
        _hostExplicitlyPaused = true;
        _hlsReady = false;
        _hlsFailed = false;
        _hlsError = null;
        _streamResolveError = null;
        _everglowStreamUrl = null;
        if (!(wasHlsMounted && _isHlsMounted)) {
          _regenerateHlsViewType();
        }
        _availableSubtitles = const [];
      });
      if (_room.isAnime) {
        _bootstrapAnime();
      } else {
        _rebuildAt(_localStartHint());
      }
      return;
    }
    final isEverglow = server.id == WatchPartyServer.everglow.id;
    await _service.updateServer(
      roomId: roomId,
      serverType: isEverglow ? 'everglow' : server.type,
      serverName: isEverglow ? 'Everglow' : server.name,
      serverHost: isEverglow ? 'everglow' : server.host,
      streamUrl: isEverglow ? null : server.streamUrl,
      subtitleUrl: isEverglow ? null : server.subtitleUrl,
      proxyEnabled: isEverglow ? false : server.proxyEnabled,
      updatedBy: uid,
    );
    if (!mounted) return;
    final wasHlsMounted = _isHlsMounted;
    setState(() {
      _room = _room
          .copyWith(
            state: 'paused',
            currentTime: 0.0,
            positionAt: DateTime.now(),
          )
          .copyWithServer(
            serverType: isEverglow ? 'everglow' : server.type,
            serverName: isEverglow ? 'Everglow' : server.name,
            serverHost: isEverglow ? 'everglow' : server.host,
            streamUrl: isEverglow ? null : server.streamUrl,
            subtitleUrl: isEverglow ? null : server.subtitleUrl,
            proxyEnabled: isEverglow ? false : server.proxyEnabled,
          );
      _hostExplicitlyPaused = true;
      _hlsReady = false;
      _hlsFailed = false;
      _hlsError = null;
      _streamResolveError = null;
      _everglowStreamUrl = null;
      if (!(wasHlsMounted && _isHlsMounted)) {
        _regenerateHlsViewType();
      }
      _availableSubtitles = const [];
      _captionsOn = true;
    });
    if (isEverglow) {
      unawaited(_resolveEverglowStream(startSeconds: 0));
    } else if (server.isHls) {
      _reloadHlsAt(0);
    } else if (_usesIframe) {
      _cinesrcReady = false;
      _iframe.src = server.streamUrl;
    }
  }

  Future<void> _endParty() async {
    if (_showEndDialog) return;
    final completer = Completer<bool>();
    setState(() {
      _showEndDialog = true;
      // Guarded: a raw `completer.complete` tear-off would throw
      // "Future already completed" on a rapid double-tap.
      _endDialogCallback = (value) {
        if (!completer.isCompleted) completer.complete(value);
      };
    });
    final result = await completer.future;
    if (result != true) return;
    await _service.endRoom(_room.id);
    await _voiceChat.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  // ─── Build ────────────────────────────────────────────────────────

  void _selectProvider(VideoSourceConfig provider) {
    if (provider.id == _selectedProvider.id) return;
    _loadTimer?.cancel();
    _contentCheckTimer?.cancel();
    _failedProviderIds.clear();
    setState(() {
      _selectedProvider = provider;
      _isLoading = true;
      _iframeFailed = false;
    });
    _loadTimer = Timer(_WatchPartyScreenStateBase._loadTimeout, () {
      if (!mounted) return;
      if (_isLoading) _onIframeLoadError();
    });
    _cinesrcReady = false;
    _iframe.src = _buildPlayerUrl(provider, startSeconds: _localStartHint());
  }

  String _formatT(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildHlsErrorCard() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dns_rounded, color: _cDeepRose, size: 48),
            const SizedBox(height: 12),
            Text(
              _isEverglowServer
                  ? 'Everglow could not start this title.'
                  : 'This server could not start playback.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitHeading.copyWith(
                color: AppColors.petalWhite,
                fontSize: 15,
              ),
            ),
            if ((_streamResolveError ?? _hlsError) != null) ...[
              const SizedBox(height: 6),
              Text(
                _streamResolveError ?? _hlsError!,
                textAlign: TextAlign.center,
                style: AppTypography.outfitMuted.copyWith(
                  color: AppColors.petalWhite.withValues(alpha: 0.60),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _errorAction(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  color: _cDeepRose,
                  onTap: () {
                    if (_isEverglowServer) {
                      unawaited(_resolveEverglowStream());
                    } else {
                      _reloadHlsAt(_localStartHint());
                    }
                  },
                ),
                _errorAction(
                  label: 'Switch server',
                  icon: Icons.dns_rounded,
                  color: _cAmber,
                  onTap: _showServerPicker,
                ),
                if (!_isEverglowServer)
                  _errorAction(
                    label: 'Open in browser',
                    icon: Icons.open_in_new_rounded,
                    color: _cGreen,
                    onTap: () async {
                      final uri = Uri.parse(_externalOpenUrl());
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitHeading.copyWith(
                color: AppColors.petalWhite,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    final active = _selectedProvider;
    final others = _providers.where((p) => p.id != active.id).toList();
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: _cDeepRose,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'This title isn\'t available on ${active.shortName}.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitHeading.copyWith(
                color: AppColors.petalWhite,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The embed returned a 404 or didn\'t respond. Try a different source below.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitMuted.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.60),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            if (others.isNotEmpty) ...[
              Text(
                'Try another source',
                style: AppTypography.outfitWhite.copyWith(
                  color: _cMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: others
                    .map(
                      (p) => GestureDetector(
                        onTap: () => _selectProvider(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _cDeepRose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _cDeepRose.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                color: _cDeepRose,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                p.name,
                                style: AppTypography.outfitHeading.copyWith(
                                  color: AppColors.petalWhite,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(_externalOpenUrl());
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.petalWhite.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.petalWhite.withValues(alpha: 0.70),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Open in browser',
                      style: AppTypography.outfitHeading.copyWith(
                        color: AppColors.petalWhite,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
