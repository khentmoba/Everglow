import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/auth_service.dart';
import '../../models/one_v_one_room.dart';
import '../../services/one_v_one_service.dart';
import 'one_v_one_game_screen.dart';

/// Pre-game UI: create a room, share the code, or paste a code to join.
/// Partner-gated: only `isCoupleUser` (khentsgdz/clairjassen) sees the
/// create/join controls. Anyone else gets a "private match" explanation.
class OneVOneLobbyScreen extends StatefulWidget {
  const OneVOneLobbyScreen({super.key});

  @override
  State<OneVOneLobbyScreen> createState() => _OneVOneLobbyScreenState();
}

class _OneVOneLobbyScreenState extends State<OneVOneLobbyScreen> {
  final _service = OneVOneService();
  final _codeController = TextEditingController();
  String? _errorText;
  bool _busy = false;
  OneVOneRoom? _activeRoom;
  Stream<OneVOneRoom?>? _roomStream;

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
      setState(() => _errorText = 'Could not create room: $e');
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
    if (!isValidRoomCode(raw)) {
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
      final joined = await _service.joinRoom(
        code: raw,
        guestUid: uid,
        guestName: auth.currentUser ?? 'Guest',
      );
      _setActiveRoom(joined);
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setActiveRoom(OneVOneRoom room) {
    setState(() {
      _activeRoom = room;
      _roomStream = _service.watchRoom(room.code);
    });
  }

  void _onRoomUpdate(OneVOneRoom room) {
    if (!mounted) return;
    setState(() => _activeRoom = room);

    // As soon as a second player joins and the room is in progress, both
    // sides should jump into the game. The host waits for the guest; the
    // guest waits for the host to flip to inProgress.
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null) return;
    final isHost = uid == room.hostUid;
    final isGuest = uid == room.guestUid;

    if (room.status == RoomStatus.inProgress &&
        ((isHost && room.guestUid != null) || isGuest)) {
      // Defer the navigation by one frame so the StreamBuilder can finish
      // rebuilding before we tear down the lobby.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OneVOneGameScreen(initialRoom: room),
          ),
        );
      });
    }
  }

  Future<void> _closeRoom() async {
    final room = _activeRoom;
    if (room != null) {
      // Best-effort: mark abandoned. If the host navigates away without
      // a guest ever joining, the doc just expires (we can add a TTL
      // cleaner later, but the collection is small enough for now).
      try {
        await _service.setStatus(code: room.code, status: RoomStatus.abandoned);
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isCouple = auth.isCoupleUser;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBackgroundGlow()),
            Column(
              children: [
                _buildHeader(auth, isCouple),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Column(
                      children: [
                        _buildTitle(),
                        const SizedBox(height: 24),
                        if (!isCouple) _buildLockedMessage() else ...[
                          if (_activeRoom == null) ...[
                            _buildCreateSection(),
                            const SizedBox(height: 24),
                            _buildJoinSection(),
                          ] else
                            _buildActiveRoomSection(_activeRoom!),
                          if (_errorText != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorText!,
                              style: GoogleFonts.outfit(
                                color: AppTheme.deepRose,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.2,
            colors: [
              AppTheme.deepRose.withValues(alpha: 0.18),
              Colors.black,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AuthService auth, bool isCouple) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _closeRoom,
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.roseQuartz),
          ),
          const Spacer(),
          Text(
            auth.currentUser == null ? '1v1 Lobby' : '${auth.currentUser} · 1v1',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              color: AppTheme.petalWhite.withValues(alpha: 0.6),
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        const Icon(
          Icons.sports_handball_rounded,
          size: 56,
          color: AppTheme.warmAmber,
        ),
        const SizedBox(height: 12),
        Text(
          '1v1 Match',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: AppTheme.roseQuartz,
            shadows: [
              BoxShadow(
                color: AppTheme.deepRose.withValues(alpha: 0.5),
                blurRadius: 18,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'You and Clair, head to head',
          style: GoogleFonts.outfit(
            color: AppTheme.petalWhite.withValues(alpha: 0.6),
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLockedMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: 0.05),
        border: Border.all(
          color: AppTheme.blushGold.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_rounded, color: AppTheme.blushGold, size: 32),
          const SizedBox(height: 12),
          Text(
            'Private match',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              color: AppTheme.petalWhite,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '1v1 is only available to the two of you. Sign in with the private passcode on the home screen.',
            style: GoogleFonts.outfit(
              color: AppTheme.petalWhite.withValues(alpha: 0.7),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSection() {
    return _LobbyCard(
      title: 'Create a match',
      body: Text(
        'You host. Share the 4-character code with Clair and she joins from her device.',
        style: GoogleFonts.outfit(
          color: AppTheme.petalWhite.withValues(alpha: 0.7),
          fontSize: 13,
        ),
      ),
      action: FilledButton(
        onPressed: _busy ? null : _create,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.warmAmber,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        ),
        child: Text(
          _busy ? '…' : 'Create room',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildJoinSection() {
    return _LobbyCard(
      title: 'Join a match',
      body: Column(
        children: [
          Text(
            'Type the code Clair sent you.',
            style: GoogleFonts.outfit(
              color: AppTheme.petalWhite.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            style: GoogleFonts.cormorantGaramond(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
              color: AppTheme.petalWhite,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'CODE',
              hintStyle: GoogleFonts.cormorantGaramond(
                color: AppTheme.petalWhite.withValues(alpha: 0.2),
                fontSize: 32,
                letterSpacing: 12,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.blushGold.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppTheme.blushGold.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.warmAmber, width: 2),
              ),
            ),
          ),
        ],
      ),
      action: FilledButton(
        onPressed: _busy ? null : _join,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.deepRose,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        ),
        child: Text(
          _busy ? '…' : 'Join',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRoomSection(OneVOneRoom room) {
    return StreamBuilder<OneVOneRoom?>(
      stream: _roomStream,
      initialData: room,
      builder: (context, snap) {
        final live = snap.data ?? room;
        if (live != room) _onRoomUpdate(live);
        final waitingForGuest = live.status == RoomStatus.waitingForGuest;
        return _LobbyCard(
          title: waitingForGuest ? 'Waiting for Clair…' : 'Match ready',
          body: Column(
            children: [
              Text(
                'Share this code with Clair',
                style: GoogleFonts.outfit(
                  color: AppTheme.petalWhite.withValues(alpha: 0.6),
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _RoomCodeDisplay(code: live.code),
              const SizedBox(height: 16),
              if (waitingForGuest)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.warmAmber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Listening for join…',
                      style: GoogleFonts.outfit(
                        color: AppTheme.petalWhite.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  '${live.guestName ?? "Guest"} joined · starting…',
                  style: GoogleFonts.outfit(
                    color: AppTheme.warmAmber,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          action: TextButton(
            onPressed: _closeRoom,
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppTheme.petalWhite.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LobbyCard extends StatelessWidget {
  const _LobbyCard({
    required this.title,
    required this.body,
    required this.action,
  });
  final String title;
  final Widget body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        border: Border.all(
          color: AppTheme.blushGold.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              color: AppTheme.petalWhite,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          body,
          const SizedBox(height: 18),
          action,
        ],
      ),
    );
  }
}

class _RoomCodeDisplay extends StatelessWidget {
  const _RoomCodeDisplay({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code $code copied'),
            backgroundColor: AppTheme.deepRose,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.warmAmber, AppTheme.deepRose],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.warmAmber.withValues(alpha: 0.3),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Forces characters typed into a code TextField to uppercase so the
/// generated/stored code (always uppercase) matches what the user types.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
