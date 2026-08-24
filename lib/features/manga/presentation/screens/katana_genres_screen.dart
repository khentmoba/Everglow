import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import '../katana/katana_header.dart';
import '../katana/katana_nav.dart';
import '../katana/katana_theme.dart';

/// The Genres page: every genre as a card with its count and
/// description, mirroring the site's genre directory.
class KatanaGenresScreen extends StatefulWidget {
  const KatanaGenresScreen({super.key});

  @override
  State<KatanaGenresScreen> createState() => _KatanaGenresScreenState();
}

class _KatanaGenresScreenState extends State<KatanaGenresScreen> {
  final KatanaService _service = KatanaService();
  List<KatanaGenre> _genres = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final genres = await _service.fetchGenres();
    if (mounted) {
      setState(() {
        _genres = genres;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KatanaColors.background,
      body: Column(
        children: [
          const KatanaHeader(active: KatanaNav.genres),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: KatanaColors.accent,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text('Genres', style: KatanaType.heading),
                          const SizedBox(height: 4),
                          Text(
                            '${_genres.length} genres',
                            style: KatanaType.small,
                          ),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 330,
                                  childAspectRatio: 2.4,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: _genres.length,
                            itemBuilder: (context, index) {
                              final genre = _genres[index];
                              return _GenreCard(genre: genre);
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  final KatanaGenre genre;
  const _GenreCard({required this.genre});

  @override
  Widget build(BuildContext context) {
    return KatanaCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => pushGenreDirectory(context, genre.slug, genre.name),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    genre.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitBold.copyWith(
                      color: KatanaColors.link,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: KatanaColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${genre.count}',
                    style: KatanaType.accent.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
            if (genre.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                genre.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KatanaType.small.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
