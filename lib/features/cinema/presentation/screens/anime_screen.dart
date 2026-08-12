import 'package:flutter/material.dart';

import 'package:everglow/features/cinema/presentation/widgets/animex/animex_shell.dart';

/// Dedicated entry for the anime rail. The full experience (home, browse,
/// schedule, search, history, my list, playlists, seasonal and the watch
/// page) lives in [AnimeXShell].
class AnimeScreen extends StatelessWidget {
  const AnimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnimeXShell();
  }
}
