import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/spotify_auth_service.dart';

/// Handles Spotify OAuth redirect: /spotify/callback?code=...&state=...
class SpotifyCallbackPage extends StatefulWidget {
  final String? code;
  final String? error;
  const SpotifyCallbackPage({super.key, this.code, this.error});

  @override
  State<SpotifyCallbackPage> createState() => _SpotifyCallbackPageState();
}

class _SpotifyCallbackPageState extends State<SpotifyCallbackPage> {
  String _status = 'Connecting to Spotify...';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _exchange());
  }

  Future<void> _exchange() async {
    if (widget.error != null) {
      setState(() => _status = 'Spotify auth failed: ${widget.error}');
      return;
    }
    if (widget.code == null || widget.code!.isEmpty) {
      setState(() => _status = 'No code returned');
      return;
    }
    final auth = context.read<SpotifyAuthService>();
    final ok = await auth.handleCallback(widget.code!);
    if (!mounted) return;
    setState(() {
      _status = ok ? 'Spotify linked! ✓' : 'Link failed — try again';
      _done = ok;
    });
    if (ok) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded, size: 48, color: AppColors.blushGold),
              const SizedBox(height: 16),
              Text(_status, style: AppTypography.outfitWhite.copyWith(fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (!_done && widget.error == null) const CircularProgressIndicator(color: AppColors.blushGold),
              if (_done || widget.error != null)
                ElevatedButton(onPressed: () => context.go('/dashboard'), child: const Text('Back to Everglow')),
            ],
          ),
        ),
      ),
    );
  }
}
