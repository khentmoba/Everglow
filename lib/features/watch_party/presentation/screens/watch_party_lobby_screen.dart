import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/watch_party_lobby.dart';

/// Full-screen room picker reached from the dashboard and from
/// `/watch-party`. The cinema tab embeds the same [WatchPartyLobby]
/// widget so both entry points show the same rooms.
class WatchPartyLobbyScreen extends StatelessWidget {
  const WatchPartyLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      appBar: AppBar(
        backgroundColor: AppColors.inkDeep,
        foregroundColor: AppColors.petalWhite,
        elevation: 0,
        title: const Text('Watch Together'),
      ),
      body: const SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.x3,
          ),
          child: WatchPartyLobby(),
        ),
      ),
    );
  }
}
