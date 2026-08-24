import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_app_bar.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../data/models/archive_movie.dart';
import '../../data/models/archive_video_file.dart';
import '../../data/services/archive_search_service.dart';

/// Search-and-download screen for the Jellyfin watch-party library.
///
/// Searches the Internet Archive open-media catalog, lists the playable
/// files inside an item, and downloads the chosen file to the browser's
/// download location. A small local helper moves completed downloads into
/// the Jellyfin library folder so the party can start from the app.
class PartyDownloadsScreen extends StatefulWidget {
  const PartyDownloadsScreen({super.key});

  @override
  State<PartyDownloadsScreen> createState() => _PartyDownloadsScreenState();
}

class _PartyDownloadsScreenState extends State<PartyDownloadsScreen> {
  final ArchiveSearchService _service = ArchiveSearchService();
  final TextEditingController _search = TextEditingController();

  List<ArchiveMovie> _results = const [];
  bool _searching = false;
  String? _searchError;

  ArchiveMovie? _selected;
  List<ArchiveVideoFile> _files = const [];
  bool _loadingFiles = false;
  String? _filesError;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch([String? query]) async {
    final text = (query ?? _search.text).trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
      _selected = null;
    });
    final results = await _service.search(text);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = results;
      _searchError = results.isEmpty
          ? 'No movies found. Try another title.'
          : null;
    });
  }

  Future<void> _openMovie(ArchiveMovie movie) async {
    setState(() {
      _selected = movie;
      _files = const [];
      _filesError = null;
      _loadingFiles = true;
    });
    final files = await _service.filesFor(movie.identifier);
    if (!mounted) return;
    setState(() {
      _loadingFiles = false;
      _files = files;
      _filesError = files.isEmpty
          ? 'No downloadable video found for this item.'
          : null;
    });
  }

  Future<void> _download(ArchiveVideoFile file) async {
    final uri = Uri.parse(file.downloadUrl);
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start the download for ${file.name}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return EverglowScaffold.cinema(
      appBar: const EverglowAppBar(title: 'Party Downloads'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _search,
              style: AppTypography.outfitWhite.copyWith(fontSize: 14),
              textInputAction: TextInputAction.search,
              onSubmitted: _runSearch,
              decoration: InputDecoration(
                hintText: 'Search public movies',
                hintStyle: AppTypography.outfitWhite.copyWith(
                  color: AppColors.mutedPurple,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.blushGold,
                ),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.blushGold,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: _runSearch,
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.blushGold,
                        ),
                      ),
                filled: true,
                fillColor: AppColors.inkDeep.withValues(alpha: 0.55),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: BorderSide(
                    color: AppColors.moonlight.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: BorderSide(
                    color: AppColors.moonlight.withValues(alpha: 0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusLg,
                  borderSide: const BorderSide(color: AppColors.deepRose),
                ),
              ),
            ),
          ),
          Expanded(
            child: _selected == null ? _buildResults() : _buildMovieDetail(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searchError != null) {
      return _buildMessage(_searchError!, Icons.search_off_rounded);
    }
    if (_searching) return _buildLoading();
    if (_results.isEmpty) {
      return _buildMessage(
        'Search for a movie to add to the party library.',
        Icons.movie_filter_rounded,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.x5,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => _buildMovieCard(_results[index]),
    );
  }

  Widget _buildMovieCard(ArchiveMovie movie) {
    return GestureDetector(
      onTap: () => _openMovie(movie),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.inkDeep.withValues(alpha: 0.6),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadius.radiusMd,
              child: Image.network(
                movie.thumbnailUrl,
                width: 88,
                height: 124,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 88,
                  height: 124,
                  color: AppColors.velvet,
                  child: const Icon(
                    Icons.movie_rounded,
                    color: AppColors.mutedPurple,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                  if (movie.year != null && movie.year!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      movie.year!,
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppColors.blushGold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.download_rounded,
                        color: AppColors.auroraTeal,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Choose file',
                        style: AppTypography.outfitBold.copyWith(
                          color: AppColors.auroraTeal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieDetail() {
    final movie = _selected!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.x5,
      ),
      children: [
        GestureDetector(
          onTap: () => setState(() => _selected = null),
          child: Row(
            children: [
              const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.blushGold,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Back to results',
                style: AppTypography.outfitBold.copyWith(
                  color: AppColors.blushGold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadius.radiusLg,
              child: Image.network(
                movie.thumbnailUrl,
                width: 120,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 120,
                  height: 170,
                  color: AppColors.velvet,
                  child: const Icon(
                    Icons.movie_rounded,
                    color: AppColors.mutedPurple,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: AppTypography.cormorantBoldWhite.copyWith(
                      fontSize: 22,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (movie.year != null && movie.year!.isNotEmpty)
                    Text(
                      movie.year!,
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppColors.blushGold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_filesError != null)
          _buildMessage(_filesError!, Icons.folder_off_rounded),
        if (_loadingFiles)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.x3),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.auroraTeal),
            ),
          )
        else
          for (final file in _files) ...[
            _buildFileRow(file),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  Widget _buildFileRow(ArchiveVideoFile file) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.6),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.auroraTeal.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitBold.copyWith(fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    file.humanSize,
                    if (file.humanLength.isNotEmpty) file.humanLength,
                    if (file.width != null && file.height != null)
                      '${file.width}x${file.height}',
                  ].where((s) => s.isNotEmpty).join('  |  '),
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.mutedPurple,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          GestureDetector(
            onTap: () => _download(file),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.auroraTeal, Color(0xFF2E9E8A)],
                ),
                borderRadius: AppRadius.radiusSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.download_rounded,
                    color: AppColors.inkDeep,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Download',
                    style: AppTypography.outfitBold.copyWith(
                      color: AppColors.inkDeep,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.auroraTeal),
    );
  }

  Widget _buildMessage(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.mutedPurple, size: 36),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.mutedPurple,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
