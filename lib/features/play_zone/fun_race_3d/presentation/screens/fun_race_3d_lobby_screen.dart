import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/auth_service.dart';
import '../../models/fun_race_3d_room.dart';
import '../../services/fun_race_3d_service.dart';
import 'fun_race_3d_1v1_game_screen.dart';

/// Pre-game UI for Fun Race 3D 1v1: create a room, share the code, or
/// paste a code to join. Partner-gated: only `isCoupleUser` (khentsgdz /
/// clairjassen) sees the create/join controls. Anyone else gets a
/// "private match" explanation.
class FunRace3DLobbyScreen extends StatefulWidget {
  const FunRace3DLobbyScreen({super.key});

  @override
  State<FunRace3DLobbyScreen> createState() => _FunRace3DLobbyScreenState();
}

class _FunRace3DLobbyScreenState extends State<FunRace3DLobbyScreen> {
  final _service = FunRace3DService();
  final _codeController = TextEditingController();
  String? _errorText;
  bool _busy = false;
  FunRace3DRoom? _activeRoom;
  Stream<FunRace3DRoom?>? _roomStream;

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _codeLength = 4;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null) {
      setState(() => _errorText = 'Not signed in.');
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final room = await _service.createRoom(
        hostUid: uid,
        hostName: auth.currentUser ?? 'Host',
      );
      _setActiveRoom(room);
    } catch (e) {
      if (mounted) setState(() => _errorText = 'Could not create room: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null) {
      setState(() => _errorText = 'Not signed in.');
      return;
    }
    final raw = _codeController.text.trim().toUpperCase();
    if (!_isValidCode(raw)) {
      setState(() => _errorText = 'Codes are 4 letters/numbers.');
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final existing = await _service.fetchRoom(raw);
      if (existing == null) {
        setState(() => _errorText = 'No room with that code.');
        return;
      }
      if (existing.hostUid == uid) {
        setState(() => _errorText = 'You can\'t join your own room.');
        return;
      }
      final joined = await _service.joinRoom(
        code: raw,
        guestUid: uid,
        guestName: auth.currentUser ?? 'Guest',
      );
      _setActiveRoom(joined);
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setActiveRoom(FunRace3DRoom room) {
    setState(() {
      _activeRoom = room;
      _roomStream = _service.watchRoom(room.code);
    });
  }

  void _leaveRoom() {
    setState(() {
      _activeRoom = null;
      _roomStream = null;
    });
  }

  bool _isValidCode(String s) {
    if (s.length != _codeLength) return false;
    for (final ch in s.codeUnits) {
      if (!_alphabet.codeUnits.contains(ch)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isCoupleUser) {
      return _privateMatchGate();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.roseQuartz),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Fun Race 3D · 1v1',
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.roseQuartz,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: _activeRoom != null
          ? _buildWaitingRoom(_activeRoom!)
          : _buildPreJoin(),
    );
  }

  Widget _privateMatchGate() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.roseQuartz),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded,
                  color: AppTheme.roseQuartz, size: 48),
              const SizedBox(height: 16),
              Text(
                'Private match',
                style: GoogleFonts.cormorantGaramond(
                  color: AppTheme.petalWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1v1 is only available to the two of you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppTheme.petalWhite.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreJoin() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Race head-to-head.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.roseQuartz,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Same track. Same start. First to finish wins.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.petalWhite.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            _buildLobbyCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'Create a room',
              subtitle: 'Get a code and share it with your partner',
              onTap: _busy ? null : _create,
            ),
            const SizedBox(height: 16),
            _buildJoinCard(),
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppTheme.deepRose,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.moonlight.withValues(alpha: 0.18),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.deepRose.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppTheme.roseQuartz, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.roseQuartz,
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.petalWhite),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.moonlight.withValues(alpha: 0.18),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.deepRose.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.login_rounded,
                    color: AppTheme.roseQuartz, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join a room',
                      style: GoogleFonts.outfit(
                        color: AppTheme.petalWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Type the code your partner sent',
                      style: GoogleFonts.outfit(
                        color: AppTheme.petalWhite.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            enabled: !_busy,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(_codeLength),
              FilteringTextInputFormatter.allow(
                RegExp('[$_alphabet${_alphabet.toLowerCase()}]'),
              ),
              _UpperCaseFormatter(),
            ],
            style: GoogleFonts.outfit(
              color: AppTheme.petalWhite,
              fontSize: 24,
              letterSpacing: 6,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'CODE',
              hintStyle: GoogleFonts.outfit(
                color: AppTheme.petalWhite.withValues(alpha: 0.3),
                letterSpacing: 6,
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.petalWhite.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.petalWhite.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.roseQuartz),
              ),
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _join,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.roseQuartz,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'JOIN',
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingRoom(FunRace3DRoom room) {
    final auth = context.read<AuthService>();
    final uid = auth.uid ?? '';
    final isHost = uid == room.hostUid;
    final partnerName = isHost
        ? (room.guestName ?? 'your partner')
        : room.hostName;
    final otherJoined = room.guestUid != null;

    return StreamBuilder<FunRace3DRoom?>(
      stream: _roomStream,
      initialData: room,
      builder: (context, snap) {
        final current = snap.data ?? room;

        // Auto-navigate both sides into the game once the second
        // player has joined and the room is `racing`.
        if (current.status == FunRace3DRoomStatus.racing &&
            (current.guestUid != null)) {
          final isInRoom = uid == current.hostUid || uid == current.guestUid;
          if (isInRoom) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      FunRace3DOneVOneGameScreen(initialRoom: current),
                ),
              );
            });
          }
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isHost ? 'Share this code' : 'You\'re in',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.roseQuartz,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isHost
                      ? 'Hand the code to your partner so they can join.'
                      : 'Waiting for the host to launch the race…',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: AppTheme.petalWhite.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                if (isHost) _buildRoomCodeDisplay(current.code),
                const SizedBox(height: 28),
                _buildPlayerRow(
                  name: current.hostName,
                  you: uid == current.hostUid,
                  state: 'Ready',
                ),
                const SizedBox(height: 12),
                _buildPlayerRow(
                  name: current.guestName ?? 'Waiting for partner…',
                  you: uid == current.guestUid,
                  state: otherJoined ? 'Ready' : 'Joining',
                ),
                const Spacer(),
                if (!otherJoined)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: AppTheme.roseQuartz,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Listening for $partnerName…',
                        style: GoogleFonts.outfit(
                          color: AppTheme.petalWhite.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  )
                else
                  Center(
                    child: Text(
                      'Get ready — race starts in a moment.',
                      style: GoogleFonts.outfit(
                        color: AppTheme.blushGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _leaveRoom,
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomCodeDisplay(String code) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Code $code copied.',
              style: GoogleFonts.outfit(),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppTheme.deepRose,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.warmAmber, AppTheme.deepRose],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warmAmber.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              code,
              style: GoogleFonts.cormorantGaramond(
                color: AppTheme.petalWhite,
                fontSize: 56,
                fontWeight: FontWeight.bold,
                letterSpacing: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'tap to copy',
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite.withValues(alpha: 0.75),
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow({
    required String name,
    required bool you,
    required String state,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.moonlight.withValues(alpha: 0.18),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            you ? Icons.person_pin_rounded : Icons.person_outline_rounded,
            color: you ? AppTheme.roseQuartz : AppTheme.petalWhite,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name + (you ? ' (you)' : ''),
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite,
                fontSize: 16,
                fontWeight: you ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            state,
            style: GoogleFonts.outfit(
              color: AppTheme.blushGold.withValues(alpha: 0.85),
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
