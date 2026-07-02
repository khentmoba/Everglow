import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/services/ai_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../../shared/widgets/shelf/scroll_edge_fade.dart';
import '../../../../shared/widgets/shelf/shelf_poster_card.dart';
import '../../../../shared/utils/text_utils.dart';

/// Mochi's Picks — AI recommendations shown as real movie poster cards.
class AIRecommendations extends StatefulWidget {
  final String? mood;
  final String title;
  final void Function(MediaItem item)? onTapItem;
  final bool autoLoad;

  const AIRecommendations({
    super.key,
    this.mood,
    this.title = "Mochi's Picks 🐱",
    this.onTapItem,
    this.autoLoad = false,
  });

  @override
  State<AIRecommendations> createState() => _AIRecommendationsState();
}

class _AIRecommendationsState extends State<AIRecommendations> {
  String? _aiText;
  List<MediaItem> _foundItems = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

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

      // Build context from Firestore directly
      final contextParts = <String>[];
      final cinemaSnapshot = await FirebaseFirestore.instance
          .collection('our_cinema')
          .orderBy('addedAt', descending: true)
          .limit(20)
          .get();
      if (cinemaSnapshot.docs.isNotEmpty) {
        final items = cinemaSnapshot.docs.map((doc) {
          final d = doc.data();
          return '${d['title'] ?? 'Unknown'} (${d['mediaType'] ?? 'movie'}) - ${d['status'] ?? 'plan to watch'}';
        }).join('\n');
        contextParts.add('Our watchlist:\n$items');
      }

      final contextStr = contextParts.join('\n\n');
      final prompt = 'Based on what we have been watching, recommend 3 movies or series we should watch next. Reply with ONLY a numbered list of titles with year, nothing else. Example: 1. Movie Name (2024)';

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

      final tmdb = TMDBService();
      final found = <MediaItem>[];
      for (final title in titles.take(5)) {
        try {
          final searchResults = await tmdb.searchMedia(title);
          if (searchResults.isNotEmpty) {
            found.add(searchResults.first);
          }
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (_) {}
      }

      setState(() {
        _aiText = stripMarkdown(result);
        _foundItems = found;
      });
    } catch (e) {
      debugPrint('Mochi picks error: $e');
      setState(() {
        _aiText = 'Mew... I couldn\'t find anything right now! Try again later? 🐱';
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
        backgroundColor: AppTheme.twilight,
        title: Text(item.title,
            style: GoogleFonts.outfit(color: AppTheme.petalWhite)),
        content: Text(item.year.isNotEmpty ? item.year : '',
            style: GoogleFonts.outfit(color: AppTheme.roseQuartz)),
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
                      color: AppTheme.blushGold.withValues(alpha: 0.4)),
                ),
                child: ClipOval(
                  child: Image.asset('assets/images/mochi_avatar.png',
                      width: 26, height: 26, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.petalWhite,
                  ),
                ),
              ),
              if (!_isLoading)
                GestureDetector(
                  onTap: _getRecommendations,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.blushGold.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ask Mochi 🐱',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.blushGold,
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
                  CircularProgressIndicator(color: AppTheme.blushGold),
                  SizedBox(height: 10),
                  Text('Mochi is thinking... 🍡',
                      style: TextStyle(
                          color: AppTheme.roseQuartz, fontSize: 13)),
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
                color: AppTheme.deepRose.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.blushGold.withValues(alpha: 0.1)),
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
                          color: AppTheme.blushGold.withValues(alpha: 0.3)),
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/images/mochi_avatar.png',
                          width: 24, height: 24, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _aiText!,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: AppTheme.petalWhite.withValues(alpha: 0.75),
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
            height: 200,
            child: ScrollEdgeFade(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _foundItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final item = _foundItems[i];
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
                          : AppTheme.deepRose,
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
