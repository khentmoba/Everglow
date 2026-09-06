import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:provider/provider.dart';
import '../../data/services/ai_service.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../cinema/presentation/widgets/netflix/netflix_poster_card.dart';
import '../../../../shared/widgets/shelf/scroll_edge_fade.dart';
import '../../../../shared/widgets/shelf/shelf_poster_card.dart';
import '../../../../shared/utils/text_utils.dart';

/// Mochi's Picks — AI recommendations shown as real movie poster cards.
class AIRecommendations extends StatefulWidget {
  final String? mood;
  final String title;
  final void Function(MediaItem item)? onTapItem;
  final bool autoLoad;

  /// Renders recommendations with Netflix-style posters (and hover
  /// previews) instead of the shared shelf card. Only the Cinema home
  /// enables this; Anime and Dashboard keep the legacy card.
  final bool netflixStyle;

  /// Lists the parent screen already fetched. When provided and non-empty,
  /// Mochi's prompt context reuses them instead of firing duplicate TMDB
  /// calls for the same data.
  final List<MediaItem>? preloadedTrending;
  final List<MediaItem>? preloadedNowPlaying;
  final List<MediaItem>? preloadedUpcoming;

  const AIRecommendations({
    super.key,
    this.mood,
    this.title = "Mochi's Picks 🐱",
    this.onTapItem,
    this.autoLoad = false,
    this.netflixStyle = false,
    this.preloadedTrending,
    this.preloadedNowPlaying,
    this.preloadedUpcoming,
  });

  @override
  State<AIRecommendations> createState() => _AIRecommendationsState();
}

class _AIRecommendationsState extends State<AIRecommendations> {
  String? _aiText;
  List<MediaItem> _foundItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Wait a bit for the provider tree and auth to be ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _getRecommendations();
        });
      });
    }
  }

  Future<void> _getRecommendations() async {
    setState(() {
      _isLoading = true;
      _aiText = null;
      _foundItems = [];
    });

    try {
      final ai = context.read<AIService>();
      final tmdb = TMDBService();

      // Build context from Firestore directly
      final contextParts = <String>[];
      final cinemaSnapshot = await FirebaseFirestore.instance
          .collection('our_cinema')
          .orderBy('addedAt', descending: true)
          .limit(20)
          .get();
      if (cinemaSnapshot.docs.isNotEmpty) {
        final items = cinemaSnapshot.docs
            .map((doc) {
              final d = doc.data();
              return '${d['title'] ?? 'Unknown'} (${d['mediaType'] ?? 'movie'}) - ${d['status'] ?? 'plan to watch'}';
            })
            .join('\n');
        contextParts.add('Our watchlist:\n$items');
      }

      // Real TMDB data so Mochi recommends actual movies. Prefer lists the
      // parent already fetched; only hit the network when none were passed.
      try {
        final trending = widget.preloadedTrending?.isNotEmpty == true
            ? widget.preloadedTrending!
            : await tmdb.fetchTrending(timeWindow: 'week');
        if (trending.isNotEmpty) {
          final list = trending
              .take(10)
              .map((m) => '${m.title} (${m.year})')
              .join(', ');
          contextParts.add('Trending movies this week: $list');
        }
      } catch (e) {
        debugPrint('[AIRecommendations] Failed to fetch trending movies: $e');
      }

      try {
        final nowPlaying = widget.preloadedNowPlaying?.isNotEmpty == true
            ? widget.preloadedNowPlaying!
            : await tmdb.fetchNowPlaying();
        if (nowPlaying.isNotEmpty) {
          final list = nowPlaying
              .take(8)
              .map((m) => '${m.title} (${m.year})')
              .join(', ');
          contextParts.add('Now playing in theaters: $list');
        }
      } catch (e) {
        debugPrint('[AIRecommendations] Failed to fetch now playing: $e');
      }

      try {
        final upcoming = widget.preloadedUpcoming?.isNotEmpty == true
            ? widget.preloadedUpcoming!
            : await tmdb.fetchUpcoming();
        if (upcoming.isNotEmpty) {
          final list = upcoming
              .take(8)
              .map((m) => '${m.title} (${m.year})')
              .join(', ');
          contextParts.add('Coming soon: $list');
        }
      } catch (e) {
        debugPrint('[AIRecommendations] Failed to fetch upcoming movies: $e');
      }

      final contextStr = contextParts.join('\n\n');
      final prompt =
          '''Based on what we have been watching and what's currently available, recommend 3 movies or series we should watch next. Pick from the trending/now playing/coming soon lists when possible — only recommend real movies that exist. Reply with ONLY a numbered list of titles with year, nothing else. Example: 1. Movie Name (2024)''';

      final result = await ai.quickAsk(
        message: prompt,
        context: contextStr.isNotEmpty ? contextStr : null,
      );

      final titles = extractTitles(result);

      if (titles.isEmpty) {
        setState(() {
          _aiText = stripMarkdown(result);
          _isLoading = false;
        });
        return;
      }

      final found = <MediaItem>[];
      for (final title in titles.take(5)) {
        try {
          final searchResults = await tmdb.searchMedia(title);
          if (searchResults.isNotEmpty) {
            found.add(searchResults.first);
          }
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          debugPrint('[AIRecommendations] TMDB search failed: $e');
        }
      }

      setState(() {
        _aiText = stripMarkdown(result);
        _foundItems = found;
      });
    } catch (e) {
      debugPrint('Mochi picks error: $e');
      setState(() {
        _aiText =
            'Mew... I couldn\'t find anything right now! Try again later? 🐱';
        _foundItems = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openDetail(MediaItem item) {
    if (widget.onTapItem != null) {
      widget.onTapItem!(item);
      return;
    }
    // Fallback: show basic dialog
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.twilight,
        title: Text(item.title, style: AppTypography.outfitWhite),
        content: Text(
          item.year.isNotEmpty ? item.year : '',
          style: AppTypography.outfitWhite.copyWith(color: AppColors.roseQuartz),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.6),
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/mochi_avatar.png',
                    width: 26,
                    height: 26,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTypography.outfitBold.copyWith(fontSize: 16),
                ),
              ),
              if (!_isLoading)
                GestureDetector(
                  onTap: _getRecommendations,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.6),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ask Mochi 🐱',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.blushGold,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Loading ─────────────────────────────────────
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.blushGold),
                  SizedBox(height: 10),
                  Text(
                    'Mochi is thinking... 🍡',
                    style: TextStyle(color: AppColors.roseQuartz, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

        // ── AI text reasoning ───────────────────────────
        if (_aiText != null && !_isLoading && _aiText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.deepRose.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.65),
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/mochi_avatar.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _aiText!,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12.5,
                        color: AppColors.petalWhite.withValues(alpha: 0.75),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Found movie poster cards ────────────────────
        if (_foundItems.isNotEmpty && !_isLoading)
          SizedBox(
            height: widget.netflixStyle && AppBreakpoint.isDesktop(context)
                ? 264
                : 200,
            child: ScrollEdgeFade(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _foundItems.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final item = _foundItems[i];
                  if (widget.netflixStyle) {
                    final width = AppBreakpoint.isDesktop(context)
                        ? 172.0
                        : 124.0;
                    return SizedBox(
                      width: width,
                      child: NetflixPosterCard(
                        item: item,
                        compact: true,
                        selfPreview: true,
                        onTap: () => _openDetail(item),
                      ),
                    );
                  }
                  return SizedBox(
                    width: 130,
                    child: ShelfPosterCard(
                      imageUrl: item.posterPath.isNotEmpty
                          ? item.posterPath
                          : item.posterUrl,
                      title: item.title,
                      subtitle: item.year.isNotEmpty ? item.year : null,
                      badge: item.mediaType.toUpperCase(),
                      badgeColor: item.isAnime
                          ? const Color(0xFFE040FB)
                          : AppColors.deepRose,
                      onTap: () => _openDetail(item),
                    ),
                  );
                },
              ),
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }
}