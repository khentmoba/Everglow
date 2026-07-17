import 'package:flutter/material.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';

/// Lightweight wrapper around a list of [MediaItem]s with loading / error
/// flags. Used by the Home and Browse tabs to track per-row fetch state.
class AnimeRowData {
  final List<MediaItem> items;
  final bool isLoading;
  final bool hasError;
  const AnimeRowData({
    this.items = const [],
    this.isLoading = false,
    this.hasError = false,
  });
}

/// Metadata for a single curated row on the Home tab (e.g. "Trending Now",
/// "Currently Airing"). The [builder] closure is invoked by the parent
/// screen to fetch the actual items — the tab widget only reads the
/// already-loaded data from [AnimeRowData].
class AnimeHomeSection {
  final String id;
  final String title;
  final IconData icon;
  final Color tint;
  final Future<List<MediaItem>> Function() builder;
  final bool isHero;

  const AnimeHomeSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.tint,
    required this.builder,
    this.isHero = false,
  });
}

/// Visual metadata for a category group header on the Browse tab
/// (title, subtitle, icon, tint colour).
class AnimeBrowseGroupMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  const AnimeBrowseGroupMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });
}
