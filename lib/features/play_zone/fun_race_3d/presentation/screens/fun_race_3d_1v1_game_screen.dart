import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/auth_service.dart';
import '../../../presentation/widgets/web_overlay_button.dart';
import '../../models/fun_race_3d_room.dart';
import '../../services/fun_race_3d_service.dart';

/// Fun Race 3D played head-to-head between two devices. Both sides
/// load the same Unity WebGL build in an iframe at the same time;
/// first to tap "I finished!" wins. The finish timestamp is written
/// to Firestore by the winner's side; the other's `markFinished` call
/// resolves the match via a transaction (see [FunRace3DService.markFinished]).
class FunRace3DOneVOneGameScreen extends StatefulWidget {
  const FunRace3DOneVOneGameScreen({super.key, required this.initialRoom});
  final FunRace3DRoom initialRoom;

  @override
  State<FunRace3DOneVOneGameScreen> createState() =>
      _FunRace3DOneVOneGameScreenState();
}

class _FunRace3DOneVOneGameScreenState
    extends State<FunRace3DOneVOneGameScreen> {
  static const String _gameSrc = 'fun_race_3d/index.html?v=1';

  late final String _viewType =
      'funrace3d-1v1-iframe-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';

  final FunRace3DService _service = FunRace3DService();

  StreamSubscription<FunRace3DRoom?>? _roomSub;
  FunRace3DRoom? _room;
  bool _booted = true;
  bool _iFinished = false;
  bool _submittingFinish = false;
  String? _errorText;

  bool get _isHost => _room?.hostUid == _localUid;
  FunRace3DSide get _mySide =>
      _isHost ? FunRace3DSide.host : FunRace3DSide.guest;
  String? get _localUid => context.read<AuthService>().uid;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    if (kIsWeb) {
      _registerIframe();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _roomSub = _service.watchRoom(widget.initialRoom.code).listen(
      (room) {
        if (!mounted) return;
        setState(() => _room = room);
      },
      onError: (e) {
        if (kDebugMode) debugPrint('Fun Race 1v1 room sub error: $e');
      },
    );
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    try {
      web.document
          .querySelector('iframe[data-everglow-fr3d-1v1="1"]')
          ?.remove();
    } catch (_) {}
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _registerIframe() {
    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = _gameSrc
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..setAttribute('data-everglow-fr3d-1v1', '1')
      ..allow = 'autoplay; fullscreen; pointer-lock; gamepad'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('webkitallowfullscreen', 'true')
      ..setAttribute('mozallowfullscreen', 'true')
      ..title = 'Fun Race 3D · 1v1'
      ..tabIndex = 0;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return iframe;
    });
  }

  Future<void> _onIFinished() async {
    if (_iFinished || _submittingFinish) return;
    final uid = _localUid;
    if (uid == null) return;
    setState(() {
      _submittingFinish = true;
      _errorText = null;
    });
    try {
      final updated = await _service.markFinished(
        code: widget.initialRoom.code,
        uid: uid,
      );
      if (!mounted) return;
      setState(() {
        _iFinished = true;
        _room = updated;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Could not record finish: $e');
    } finally {
      if (mounted) setState(() => _submittingFinish = false);
    }
  }

  Future<void> _restart() async {
    if (!_isHost) return;
    setState(() {
      _iFinished = false;
      _errorText = null;
    });
    try {
      final updated = await _service.resetForRematch(
        code: widget.initialRoom.code,
      );
      if (!mounted) return;
      setState(() => _room = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Could not start rematch: $e');
    }
  }

  void _restartIframe() {
    try {
      final iframe =
          web.document.querySelector('iframe[data-everglow-fr3d-1v1="1"]')
              as web.HTMLIFrameElement?;
      final w = iframe?.contentWindow;
      if (w != null) w.location.reload();
    } catch (_) {}
  }

  Future<void> _close() async {
    try {
      await _service.setAbandoned(code: widget.initialRoom.code);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.roseQuartz),
        ),
      );
    }

    if (room.status == FunRace3DRoomStatus.finished) {
      return _buildFinishedScreen(room);
    }

    if (room.status == FunRace3DRoomStatus.abandoned) {
      return _buildAbandonedScreen();
    }

    return _buildRacingScreen(room);
  }

  Widget _buildRacingScreen(FunRace3DRoom room) {
    final myFinished = _iFinished || room.didFinish(_mySide);
    final partnerFinished =
        room.didFinish(_isHost ? FunRace3DSide.guest : FunRace3DSide.host);

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (kIsWeb)
              Positioned.fill(
                child: HtmlElementView(viewType: _viewType),
              )
            else
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Text(
                    'Fun Race 3D is only available in the web build.',
                    style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                  ),
                ),
              ),
            if (_booted)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: _buildTopBar(room),
              ),
            if (_booted)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 20,
                child: _buildFinishArea(myFinished, partnerFinished),
              ),
            if (_errorText != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRose.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorText!,
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(FunRace3DRoom room) {
    return Row(
      children: [
        WebOverlayButton(icon: Icons.close_rounded, onTap: _close),
        const SizedBox(width: 12),
        Expanded(child: _buildOpponentPill(room)),
        const SizedBox(width: 12),
        WebOverlayButton(
          icon: Icons.replay_rounded,
          onTap: _restartIframe,
          tooltip: 'Restart track',
        ),
      ],
    );
  }

  Widget _buildOpponentPill(FunRace3DRoom room) {
    final partnerName = _isHost
        ? (room.guestName ?? 'Partner')
        : room.hostName;
    final partnerSide =
        _isHost ? FunRace3DSide.guest : FunRace3DSide.host;
    final partnerFinished = room.didFinish(partnerSide);
    return WebOverlayPill(
      text: partnerFinished
          ? '$partnerName finished'
          : 'Waiting for $partnerName',
      leadingIcon: partnerFinished
          ? Icons.check_circle_rounded
          : Icons.radio_button_unchecked_rounded,
      leadingIconColor: partnerFinished
          ? AppTheme.blushGold
          : AppTheme.petalWhite.withValues(alpha: 0.6),
      background: Colors.black.withValues(alpha: 0.45),
      borderColor: AppTheme.petalWhite.withValues(alpha: 0.18),
      textColor: AppTheme.petalWhite,
    );
  }

  Widget _buildFinishArea(bool myFinished, bool partnerFinished) {
    if (myFinished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.blushGold.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.blushGold, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                partnerFinished
                    ? 'Both finished. Resolving match…'
                    : 'Finish recorded. Waiting for your partner…',
                style: GoogleFonts.outfit(
                  color: AppTheme.petalWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildBigFinishButton();
  }

  Widget _buildBigFinishButton() {
    return WebOverlayTextButton(
      label: 'I FINISHED!',
      icon: Icons.flag_rounded,
      onTap: _onIFinished,
      busy: _submittingFinish,
    );
  }

  Widget _buildFinishedScreen(FunRace3DRoom room) {
    final auth = context.read<AuthService>();
    final uid = auth.uid ?? '';
    final iWon = room.winnerUid == uid;
    final isHost = _isHost;
    final winnerName = (room.winnerUid == room.hostUid)
        ? room.hostName
        : (room.guestName ?? 'Guest');
    final myFinish = _isHost ? room.hostFinishedAt : room.guestFinishedAt;
    final theirFinish = _isHost ? room.guestFinishedAt : room.hostFinishedAt;
    final marginMs = _computeMarginMs(myFinish, theirFinish);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(
                iWon
                    ? Icons.emoji_events_rounded
                    : Icons.sentiment_dissatisfied_rounded,
                size: 80,
                color: iWon ? AppTheme.blushGold : AppTheme.deepRose,
              ),
              const SizedBox(height: 12),
              Text(
                iWon ? 'You win!' : '$winnerName wins',
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  color: AppTheme.roseQuartz,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                iWon
                    ? 'You crossed the line first.'
                    : '$winnerName crossed the line first.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppTheme.petalWhite.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              _buildResultRow(
                name: room.hostName,
                you: uid == room.hostUid,
                finish: room.hostFinishedAt,
                isWinner: room.winnerUid == room.hostUid,
                margin: _isHost ? marginMs : null,
              ),
              const SizedBox(height: 12),
              _buildResultRow(
                name: room.guestName ?? 'Guest',
                you: uid == room.guestUid,
                finish: room.guestFinishedAt,
                isWinner: room.winnerUid == room.guestUid,
                margin: !_isHost ? marginMs : null,
              ),
              const Spacer(),
              if (isHost)
                _buildPrimaryButton(
                  label: 'REMATCH',
                  onTap: () {
                    _restart();
                    _restartIframe();
                  },
                )
              else
                _buildPrimaryButton(
                  label: 'WAITING FOR REMATCH…',
                  onTap: null,
                ),
              const SizedBox(height: 12),
              _buildSecondaryButton(
                label: 'BACK TO HUB',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _computeMarginMs(Timestamp? mine, Timestamp? theirs) {
    if (mine == null || theirs == null) return null;
    final diff = mine.millisecondsSinceEpoch - theirs.millisecondsSinceEpoch;
    return diff.abs();
  }

  Widget _buildResultRow({
    required String name,
    required bool you,
    required Timestamp? finish,
    required bool isWinner,
    int? margin,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isWinner
            ? AppTheme.blushGold.withValues(alpha: 0.12)
            : AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner
              ? AppTheme.blushGold.withValues(alpha: 0.6)
              : AppTheme.moonlight.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isWinner
                ? Icons.emoji_events_rounded
                : Icons.flag_outlined,
            color: isWinner ? AppTheme.blushGold : AppTheme.petalWhite,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name + (you ? ' (you)' : ''),
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite,
                fontSize: 16,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (margin != null && !isWinner)
            Text(
              '+$margin ms',
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            )
          else if (isWinner)
            const Icon(Icons.check_rounded,
                color: AppTheme.blushGold, size: 22),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.warmAmber, AppTheme.deepRose],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: onTap == null
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.warmAmber.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.petalWhite.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: AppTheme.petalWhite.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAbandonedScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_rounded,
                  color: AppTheme.deepRose, size: 64),
              const SizedBox(height: 12),
              Text(
                'Match cancelled',
                style: GoogleFonts.cormorantGaramond(
                  color: AppTheme.petalWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildSecondaryButton(
                label: 'BACK TO HUB',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

