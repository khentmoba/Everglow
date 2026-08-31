import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../cinema/data/services/ani_zip_service.dart';
import '../../../cinema/data/services/video_source_service.dart';
import '../../../cinema/data/models/video_source_config.dart';
import '../../../../core/services/auth_service.dart';
import '../../data/models/watch_party_room.dart';
import '../../data/models/watch_party_server.dart';
import '../../data/services/voice_chat_service.dart';
import '../../data/services/watch_party_server_service.dart';
import '../../data/services/watch_party_service.dart';
import '../widgets/hls_server_player.dart';
import '../widgets/server_picker_sheet.dart';
import '../widgets/voice_chat_overlay.dart';
import '../widgets/watch_party_chat_drawer.dart';
import '../../../../core/theme/app_typography.dart';
part 'watch_party_widgets.dart';
part 'watch_party_state_base.dart';
part 'watch_party_state_core2.dart';

// ─── Color tokens (mirror cinema_screen.dart / episode_drawer.dart) ──
const _cRose = AppColors.roseQuartz;
const _cCard = AppColors.shimmerBase;
const _cDeepRose = AppColors.deepRose;
const _cAmber = AppColors.warmAmber;
const _cWhite = AppColors.petalWhite;
const _cMuted = AppColors.mutedPurple;
const _cGreen = AppColors.success;

/// Real-time synchronized playback screen for the couple.
///
/// Built on top of the same third-party embed providers as the regular
/// [VideoPlayerScreen] (Videasy / VidLink / 2Embed / etc.) but with a
/// coordination layer that mirrors the host's playback state to the
/// partner's iframe. See `lib/features/watch_party/data/services/watch_party_service.dart`
/// for the room lifecycle; this file handles the UI + sync timing.
///
/// Why we don't get pixel-perfect sync:
///   The iframes are cross-origin and don't expose their timeline, so
///   we can't read `currentTime` or call `play()/pause()` on them
///   directly. Instead both clients keep a local clock anchored to
///   the most recent Firestore update, and when the host's time
///   diverges from the partner's by more than [_resyncThreshold] we
///   rebuild the iframe with a fresh `?start=` hint. This isn't a
///   frame-perfect Netflix Party — it's a "we're watching the same
///   scene within a few seconds" best effort, which is good enough
///   for a movie night across town.
class WatchPartyScreen extends StatefulWidget {
  /// The room to join. The host constructs this from the picked media
  /// + their auth info; the partner receives the same `id` from
  /// Firestore when they tap Resume on the dashboard.
  final WatchPartyRoom initialRoom;

  /// True if the current user is the room's host. Drives UI affordances
  /// (host gets the play/pause button; partner gets Resync + the
  /// "follow host" auto-resync loop).
  final bool isHost;

  const WatchPartyScreen({
    super.key,
    required this.initialRoom,
    required this.isHost,
  });

  @override
  State<WatchPartyScreen> createState() => _WatchPartyScreenState();
}

class _WatchPartyScreenState extends _WatchPartyScreenStateCore2 {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildCinemaTopBar(),
            Expanded(
              child: SingleChildScrollView(
                controller: _pageScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCinemaPlayerStage(),
                    _buildCinemaMetadata(),
                    _buildCinemaServerSelector(),
                    const SizedBox(height: AppSpacing.x3),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  /// Cinema-style 16:9 stage. Keeps the HLS player / iframe in the same
  /// platform view, with loading, error, sync, voice, and chat overlays.
  Widget _buildCinemaPlayerStage() {
    final maxPlayerHeight = (MediaQuery.sizeOf(context).height - 320).clamp(
      240.0,
      double.infinity,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxPlayerHeight),
      child: RepaintBoundary(
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (_isHlsServer)
                  HlsServerPlayer(
                    streamUrl: _hlsStreamUrl,
                    subtitleUrl: _room.subtitleUrl,
                    startSeconds: _localStartHint(),
                    autoplay: !_hostExplicitlyPaused,
                    viewType: _hlsViewType,
                    controller: _hlsController,
                    onReady: () {
                      if (!mounted) return;
                      setState(() {
                        _hlsReady = true;
                        _hlsFailed = false;
                        _hlsError = null;
                      });
                    },
                    onTimeUpdate: (time) {
                      _anchorTime = time;
                      _anchorEpoch = DateTime.now();
                    },
                    onError: (message) {
                      if (!mounted) return;
                      debugPrint(
                        '[WatchPartyScreen] HLS server error: $message',
                      );
                      setState(() {
                        _hlsFailed = true;
                        _hlsError = message;
                      });
                    },
                  )
                else if (!_iframeFailed)
                  HtmlElementView(viewType: _viewType),
                if (_isHlsServer && !_hlsReady && !_hlsFailed)
                  _WatchPartyCinematicLoader(serverName: _activeServerLabel),
                if (_isLoading && !_iframeFailed && !_isHlsServer)
                  _WatchPartyCinematicLoader(serverName: _activeServerLabel),
                if (_hlsFailed) _buildHlsErrorCard(),
                if (_iframeFailed) _buildErrorCard(),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _buildSyncOverlay(),
                ),
                VoiceChatOverlay(
                  service: _voiceChat,
                  partnerName: _partnerName,
                ),
                WatchPartyChatDrawer(roomId: _room.id),
                if (_showEndDialog) _buildEndDialog(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _activeServerLabel {
    if (_room.streamUrl != null) {
      return _room.serverName ?? (_room.serverType == 'hls' ? 'HLS' : 'Embed');
    }
    return _selectedProvider.shortName;
  }

  Widget _buildCinemaTopBar() {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inkDeep,
        border: Border(
          bottom: BorderSide(
            color: AppColors.moonlight.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _CinemaPillButton(
            icon: Icons.arrow_back_ios_new_rounded,
            label: 'Back',
            compact: compact,
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: compact ? 8 : 14),
          if (!compact) ...[
            Expanded(
              child: Text(
                _room.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cormorantSemiBoldWhite.copyWith(
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          _CinemaPillButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Try Another Source',
            accent: true,
            compact: compact,
            onTap: _showServerPicker,
          ),
          SizedBox(width: compact ? 6 : 8),
          _buildServerChip(compact: compact),
          SizedBox(width: compact ? 6 : 8),
          _CinemaPillButton(
            icon: Icons.close_rounded,
            label: 'End',
            compact: compact,
            accent: true,
            onTap: _endParty,
          ),
        ],
      ),
    );
  }

  Widget _buildCinemaMetadata() {
    final isTv = _room.mediaType == 'tv';
    final activeServer = _activeServerLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _metaBadge(Icons.source_rounded, activeServer, accent: true),
              _metaBadge(
                isTv ? Icons.tv_rounded : Icons.movie_rounded,
                isTv ? 'TV Show' : 'Movie',
                tint: AppColors.softLavender,
              ),
              if (isTv)
                _metaBadge(
                  Icons.layers_rounded,
                  'S${_room.season ?? 1} E${_room.episode ?? 1}',
                  tint: AppColors.moonlight,
                ),
              _metaBadge(
                _hostExplicitlyPaused
                    ? Icons.pause_rounded
                    : Icons.sensors_rounded,
                _hostExplicitlyPaused ? 'Paused by host' : 'Synced live',
                tint: _hostExplicitlyPaused ? _cAmber : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Watching together with $_partnerName',
            style: AppTypography.outfitWhite.copyWith(
              color: AppColors.textMedium,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaBadge(
    IconData icon,
    String label, {
    bool accent = false,
    Color? tint,
  }) {
    final chipColor = tint ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.deepRose.withValues(alpha: 0.15)
            : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: accent
              ? AppColors.deepRose.withValues(alpha: 0.5)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: accent ? AppColors.roseQuartz : chipColor,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.outfitHeading.copyWith(
              color: accent ? AppColors.roseQuartz : AppColors.textMedium,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinemaServerSelector() {
    final isHls = _room.serverType == 'hls';
    final serverName = _room.streamUrl == null
        ? _selectedProvider.name
        : (_room.serverName ?? 'Server');
    final desc = _room.streamUrl == null
        ? _selectedProvider.desc
        : isHls
        ? 'Self-hosted HLS stream · real play/pause/seek sync'
        : 'Embedded server · best-effort sync';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: GestureDetector(
        onTap: _showServerPicker,
        child: Container(
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.x2),
            gradient: const LinearGradient(
              colors: [AppColors.deepRose, AppColors.softLavender],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.inkDeep.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.x2 - 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isHls ? AppColors.success : AppColors.blushGold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isHls ? AppColors.success : AppColors.blushGold)
                            .withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server: $serverName',
                        style: AppTypography.outfitHeading.copyWith(
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: AppTypography.outfitWhite.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.petalWhite,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncOverlay() {
    final pillColor = _isResyncing
        ? _cAmber
        : _hostExplicitlyPaused
        ? _cMuted
        : _cGreen;
    final pausedByMe = _hostExplicitlyPaused && _room.updatedBy == _myUid;
    final label = _isResyncing
        ? 'Syncing to ${_formatT(_room.currentTime)}…'
        : _hostExplicitlyPaused
        ? (pausedByMe ? 'You paused' : '$_partnerName paused')
        : 'Synced · ${_formatT(_displayedTime)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: pillColor.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: pillColor,
                  shape: BoxShape.circle,
                  boxShadow: pillColor == _cGreen
                      ? [
                          BoxShadow(
                            color: _cGreen.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.outfitHeading.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (!widget.isHost) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.black,
        child: Row(
          children: [
            _buildServerChip(compact: true),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You\'re ${_formatT(_displayedTime)} in',
                style: AppTypography.outfitWhite.copyWith(
                  color: _cWhite.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              label: _hostExplicitlyPaused ? 'Play video' : 'Pause video',
              button: true,
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _cDeepRose.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _cDeepRose.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _hostExplicitlyPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hostExplicitlyPaused ? 'RESUME' : 'PAUSE',
                        style: AppTypography.outfitWhite.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.1,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(color: Colors.black),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildServerChip(compact: true),
          const SizedBox(width: 10),
          Semantics(
            label: _hostExplicitlyPaused ? 'Play video' : 'Pause video',
            button: true,
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_cDeepRose, AppColors.rosePressed],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _cDeepRose.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hostExplicitlyPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hostExplicitlyPaused ? 'RESUME' : 'PAUSE',
                      style: AppTypography.outfitWhite.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1.2,
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

  Widget _buildServerChip({bool compact = false}) {
    final active = _room.streamUrl != null;
    final color = active
        ? (_room.serverType == 'hls' ? _cGreen : _cAmber)
        : _cMuted;
    final label = active ? (_room.serverName ?? 'Server') : 'Auto';
    return Semantics(
      label: 'Choose playback server',
      button: true,
      child: GestureDetector(
        onTap: _showServerPicker,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.dns_rounded : Icons.dns_outlined,
                color: color,
                size: 12,
              ),
              if (!compact) ...[
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      color: Colors.white,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndDialog() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {},
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'End the night?',
                  style: AppTypography.cormorantBold.copyWith(
                    fontSize: 22,
                    color: _cWhite,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your partner will be sent back to the cinema.',
                  textAlign: TextAlign.center,
                  style: AppTypography.outfitWhite.copyWith(
                    color: _cWhite.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _endDialogCallback?.call(false);
                        setState(() => _showEndDialog = false);
                      },
                      child: Text(
                        'Stay',
                        style: AppTypography.outfitBold.copyWith(color: _cRose),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _endDialogCallback?.call(true);
                        setState(() => _showEndDialog = false);
                      },
                      child: Text(
                        'End',
                        style: AppTypography.outfitHeading.copyWith(
                          color: _cDeepRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
