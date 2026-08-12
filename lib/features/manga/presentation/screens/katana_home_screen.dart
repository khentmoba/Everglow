import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';
import 'package:everglow/features/manga/presentation/katana/katana_header.dart';
import 'package:everglow/features/manga/presentation/katana/katana_item_card.dart';
import 'package:everglow/features/manga/presentation/katana/katana_nav.dart';
import 'package:everglow/features/manga/presentation/katana/katana_theme.dart';

/// Manga Katana home: Latest Updates list, Hot Manga rail and the
/// Genres widget, laid out like the site (content left, widgets right
/// on desktop).
class KatanaHomeScreen extends StatefulWidget {
  const KatanaHomeScreen({super.key});

  @override
  State<KatanaHomeScreen> createState() => _KatanaHomeScreenState();
}

class _KatanaHomeScreenState extends State<KatanaHomeScreen> {
  final KatanaService _service = KatanaService();
  KatanaHomeData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchHome();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not reach Manga Katana. Pull down to retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KatanaColors.background,
      body: Column(
        children: [
          const KatanaHeader(active: KatanaNav.home),
          Expanded(
            child: RefreshIndicator(
              color: KatanaColors.accent,
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) return _buildLoading();
    if (_error != null && (_data == null || _data!.latest.isEmpty)) {
      return _buildError();
    }
    final data = _data ?? const KatanaHomeData();
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 960;

    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: _buildLatest(data.latest)),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 330,
                        child: Column(
                          children: [
                            _buildGenresWidget(data.genres),
                            const SizedBox(height: 16),
                            _buildHotWidget(data.hot),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLatest(data.latest),
                      const SizedBox(height: 20),
                      _buildHotWidget(data.hot),
                      const SizedBox(height: 20),
                      _buildGenresWidget(data.genres),
                    ],
                  ),
          ),
        ),
      ],
    );
    return content;
  }

  Widget _buildLoading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: KatanaCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 110,
                    decoration: BoxDecoration(
                      color: KatanaColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: KatanaColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 10,
                          width: 180,
                          decoration: BoxDecoration(
                            color: KatanaColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 10,
                          width: 120,
                          decoration: BoxDecoration(
                            color: KatanaColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: KatanaColors.textLight),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center, style: KatanaType.body),
            const SizedBox(height: 14),
            KatanaButton(label: 'Retry', icon: Icons.refresh_rounded, onTap: _load),
          ],
        ),
      ),
    );
  }

  Widget _buildLatest(List<KatanaManga> latest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KatanaSectionHeader(title: 'Latest Updates'),
        const SizedBox(height: 12),
        if (latest.isEmpty)
          KatanaCard(
            padding: const EdgeInsets.all(20),
            child: Text('Nothing updated yet.', style: KatanaType.small),
          )
        else
          for (final manga in latest) ...[
            KatanaItemCard(manga: manga),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildHotWidget(List<KatanaManga> hot) {
    if (hot.isEmpty) return const SizedBox.shrink();
    return KatanaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KatanaSectionHeader(
            title: 'Hot Manga',
            trailing: const Icon(Icons.local_fire_department_rounded,
                color: KatanaColors.orange, size: 20),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: hot.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => SizedBox(
                width: 96,
                child: KatanaCompactCard(manga: hot[index], width: 96),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenresWidget(List<KatanaGenre> genres) {
    if (genres.isEmpty) return const SizedBox.shrink();
    return KatanaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KatanaSectionHeader(title: 'Genres'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final genre in genres)
                GestureDetector(
                  onTap: () =>
                      pushGenreDirectory(context, genre.slug, genre.name),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: KatanaColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: KatanaColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          genre.name,
                          style: AppTypography.outfitWhite.copyWith(
                            color: KatanaColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (genre.count > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${genre.count})',
                            style: KatanaType.small.copyWith(fontSize: 10.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
