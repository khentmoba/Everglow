import 'package:flutter/material.dart';

import '../widgets/animex/animex_shell.dart';

/// Dedicated entry for the anime rail. The full experience (home, browse,
/// schedule, search, history, my list, playlists, seasonal and the watch
/// page) lives in [AnimeXShell].
class AnimeScreen extends StatelessWidget {
  final int? initialAnilistId;
  final int? initialMalId;
  final int? initialTmdbId;
  final String? initialSource;
  final String? initialType;
  final String? initialFormat;
  final String? initialTitle;
  final String? initialPoster;
  final int? initialEpisode;

  const AnimeScreen({
    super.key,
    this.initialAnilistId,
    this.initialMalId,
    this.initialTmdbId,
    this.initialSource,
    this.initialType,
    this.initialFormat,
    this.initialTitle,
    this.initialPoster,
    this.initialEpisode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimeXShell(
      initialAnilistId: initialAnilistId,
      initialMalId: initialMalId,
      initialTmdbId: initialTmdbId,
      initialSource: initialSource,
      initialType: initialType,
      initialFormat: initialFormat,
      initialTitle: initialTitle,
      initialPoster: initialPoster,
      initialEpisode: initialEpisode,
    );
  }
}
