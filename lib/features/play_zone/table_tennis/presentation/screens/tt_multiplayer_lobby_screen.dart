import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/auth_service.dart';
import '../../services/tt_multiplayer_service.dart';
import 'tt_multiplayer_game_screen.dart';
import 'package:everglow/core/theme/app_typography.dart';

class TTMultiplayerLobbyScreen extends StatefulWidget {
  const TTMultiplayerLobbyScreen({super.key});

  @override
  State<TTMultiplayerLobbyScreen> createState() =>
      _TTMultiplayerLobbyScreenState();
}

class _TTMultiplayerLobbyScreenState extends State<TTMultiplayerLobbyScreen> {
  final TTMultiplayerService _mpService = TTMultiplayerService();
  StreamSubscription? _guestSub;
  bool _searching = false;
  String? _roomId;
  String? _statusText;
  int _countdown = 0;

  @override
  void dispose() {
    _guestSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sports_tennis_rounded,
                size: 64,
                color: AppTheme.warmAmber,
              ),
              const SizedBox(height: 16),
              Text(
                'Table Tennis 1v1',
                style: AppTypography.cormorantBold.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                'Play against your partner',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 14,
                  color: AppTheme.petalWhite.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 48),
              if (!_searching && _countdown == 0) _buildFindMatchButton(),
              if (_searching) _buildSearchingState(),
              if (_countdown > 0) _buildCountdown(),
              const SizedBox(height: 32),
              if (_roomId != null)
                Text(
                  'Room: $_roomId',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    color: AppTheme.petalWhite.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindMatchButton() {
    return GestureDetector(
      onTap: _findMatch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.warmAmber, AppTheme.deepRose],
          ),
          borderRadius: BorderRadius.all(Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x4Df5a623),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          'Find Match',
          style: AppTypography.outfitWhite.copyWith(
            fontWeight: FontWeight.w900,
            color: AppTheme.petalWhite,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingState() {
    return Column(
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: AppTheme.warmAmber,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _statusText ?? 'Searching for opponent...',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 16,
            color: AppTheme.petalWhite,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 600 + i * 200),
              builder: (_, v, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.warmAmber.withValues(alpha: v),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: _cancelSearch,
          child: Text(
            'Cancel',
            style: AppTypography.outfitWhite.copyWith(
              color: AppTheme.petalWhite.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    return Column(
      children: [
        Text(
          'Match found!',
          style: AppTypography.outfitBold.copyWith(
            fontSize: 20,
            color: AppTheme.warmAmber,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$_countdown',
          style: AppTypography.cormorantBold.copyWith(fontSize: 72),
        ),
      ],
    );
  }

  Future<void> _findMatch() async {
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null) return;

    setState(() {
      _searching = true;
      _statusText = 'Searching for opponent...';
    });

    try {
      final existing = await _mpService.findOpenRoom(myUid: uid);
      if (!mounted) return;

      if (existing != null) {
        await _mpService.joinRoom(roomId: existing.id, guestUid: uid);
        if (!mounted) return;
        _startCountdown(existing.id, false);
      } else {
        final room = await _mpService.createRoom(hostUid: uid);
        if (!mounted) return;
        _waitForGuest(room.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _statusText = 'Error: ${e.toString()}';
      });
    }
  }

  void _waitForGuest(String roomId) {
    _guestSub?.cancel();
    _guestSub = _mpService.watchRoom(roomId).listen((room) {
      if (!mounted) return;
      if (room.guestUid != null) {
        _startCountdown(roomId, true);
      }
    });
  }

  void _startCountdown(String roomId, bool isHost) {
    setState(() {
      _roomId = roomId;
      _countdown = 3;
      _searching = false;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_countdown > 1) {
        setState(() => _countdown--);
        return true;
      }
      setState(() => _countdown = 0);
      if (!mounted) return false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              TTMultiplayerGameScreen(roomId: roomId, isHost: isHost),
        ),
      );
      return false;
    });
  }

  void _cancelSearch() {
    _guestSub?.cancel();
    if (_roomId != null) {
      _mpService.deleteRoom(roomId: _roomId!);
    }
    setState(() {
      _searching = false;
      _roomId = null;
      _statusText = null;
    });
  }
}
