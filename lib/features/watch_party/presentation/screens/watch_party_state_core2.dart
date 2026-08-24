part of 'watch_party_screen_web.dart';

abstract class _WatchPartyScreenStateCore2 extends _WatchPartyScreenStateCore {
  Future<void> _showServerPicker() async {
    final serverService = WatchPartyServerService();
    final current = _room.streamUrl == null
        ? null
        : WatchPartyServer.fromRoom(
            serverType: _room.serverType ?? 'embed',
            serverName: _room.serverName ?? 'Server',
            serverHost: _room.serverHost ?? 'custom',
            streamUrl: _room.streamUrl ?? '',
            subtitleUrl: _room.subtitleUrl,
            proxyEnabled: _room.proxyEnabled,
          );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ServerPickerSheet(
        servers: serverService.servers,
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
      setState(() {
        _room = _room
            .copyWith(state: 'paused', currentTime: 0.0)
            .copyWithServer();
        _hostExplicitlyPaused = true;
        _hlsReady = false;
        _hlsFailed = false;
        _hlsError = null;
      });
      return;
    }
    await _service.updateServer(
      roomId: roomId,
      serverType: server.type,
      serverName: server.name,
      serverHost: server.host,
      streamUrl: server.streamUrl,
      subtitleUrl: server.subtitleUrl,
      proxyEnabled: server.proxyEnabled,
      updatedBy: uid,
    );
    if (!mounted) return;
    setState(() {
      _room = _room
          .copyWith(state: 'paused', currentTime: 0.0)
          .copyWithServer(
            serverType: server.type,
            serverName: server.name,
            serverHost: server.host,
            streamUrl: server.streamUrl,
            subtitleUrl: server.subtitleUrl,
            proxyEnabled: server.proxyEnabled,
          );
      _hostExplicitlyPaused = true;
      _hlsReady = false;
      _hlsFailed = false;
      _hlsError = null;
    });
    if (server.isHls) {
      _reloadHlsAt(0);
    } else if (_usesIframe) {
      _iframe.src = server.streamUrl;
    }
  }

  Future<void> _endParty() async {
    if (_showEndDialog) return;
    final completer = Completer<bool>();
    setState(() {
      _showEndDialog = true;
      _endDialogCallback = completer.complete;
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
              'This server could not start playback.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitHeading.copyWith(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            if (_hlsError != null) ...[
              const SizedBox(height: 6),
              Text(
                _hlsError!,
                textAlign: TextAlign.center,
                style: AppTypography.outfitMuted.copyWith(
                  color: Colors.white60,
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
                  onTap: () => _reloadHlsAt(_localStartHint()),
                ),
                _errorAction(
                  label: 'Switch server',
                  icon: Icons.dns_rounded,
                  color: _cAmber,
                  onTap: _showServerPicker,
                ),
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
                color: Colors.white,
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
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The embed returned a 404 or didn\'t respond. Try a different source below.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitMuted.copyWith(
                color: Colors.white60,
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
                                  color: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Open in browser',
                      style: AppTypography.outfitHeading.copyWith(
                        color: Colors.white,
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
