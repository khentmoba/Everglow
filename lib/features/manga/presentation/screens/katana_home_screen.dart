import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import '../katana/katana_header.dart';
import '../katana/katana_item_card.dart';
import '../katana/katana_nav.dart';
import '../katana/katana_pagination.dart';
import '../katana/katana_theme.dart';

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

  // Content-type browsing: 'all' shows the live Latest Updates feed;
  // 'manga' / 'manhwa' / 'manhua' show that type's full catalog.
  String _type = 'all';
  List<KatanaManga> _typeItems = const [];
  int _typePage = 1;
  bool _typeHasNext = false;
  bool _typeLoading = false;
  String? _typeError;

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

  void _selectType(String type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _typePage = 1;
      _typeItems = const [];
      _typeError = null;
    });
    if (type != 'all') _loadType();
  }

  Future<void> _loadType() async {
    setState(() {
      _typeLoading = true;
      _typeError = null;
    });
    try {
      final result = await _service.fetchByType(
        _type,
        page: _typePage,
        orderBy: 'latest',
      );
      if (mounted) {
        setState(() {
          _typeItems = result.items;
          _typeHasNext = result.hasNext;
          _typeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _typeLoading = false;
          _typeError = 'Could not load ${_typeLabel(_type)} titles.';
        });
      }
    }
  }

  void _changeTypePage(int page) {
    if (page < 1) return;
    setState(() => _typePage = page);
    _loadType();
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
              onRefresh: () async {
                await Future.wait([_load(), if (_type != 'all') _loadType()]);
              },
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
            child: _buildTypeChips(),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _type == 'all'
                            ? _buildLatest(data.latest)
                            : _buildTypeList(),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 330,
                        child: Column(
                          children: [
                            _buildGenresWidget(data.genres),
                            if (_type == 'all') ...[
                              const SizedBox(height: 16),
                              _buildHotWidget(data.hot),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _type == 'all'
                          ? _buildLatest(data.latest)
                          : _buildTypeList(),
                      if (_type == 'all') ...[
                        const SizedBox(height: 20),
                        _buildHotWidget(data.hot),
                      ],
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

  Widget _buildTypeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final type in const ['all', 'manga', 'manhwa', 'manhua']) ...[
            _TypeChip(
              label: type == 'all'
                  ? 'All'
                  : '${type[0].toUpperCase()}${type.substring(1)}',
              icon: type == 'all'
                  ? Icons.all_inclusive_rounded
                  : Icons.menu_book_rounded,
              selected: _type == type,
              onTap: () => _selectType(type),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KatanaSectionHeader(
          title: _typeLabel(_type),
          trailing: Text(_typeEyebrow(_type), style: KatanaType.small),
        ),
        const SizedBox(height: 12),
        if (_typeLoading && _typeItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: KatanaColors.accent),
            ),
          )
        else if (_typeError != null)
          KatanaCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  _typeError!,
                  textAlign: TextAlign.center,
                  style: KatanaType.body,
                ),
                const SizedBox(height: 12),
                KatanaButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onTap: _loadType,
                ),
              ],
            ),
          )
        else if (_typeItems.isEmpty)
          KatanaCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No ${_typeLabel(_type)} titles yet.',
              style: KatanaType.small,
            ),
          )
        else ...[
          for (final manga in _typeItems) ...[
            KatanaItemCard(manga: manga),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          KatanaPagination(
            page: _typePage,
            hasPrev: _typePage > 1,
            hasNext: _typeHasNext,
            onPageChanged: _changeTypePage,
          ),
        ],
      ],
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'manga':
        return 'Manga';
      case 'manhwa':
        return 'Manhwa';
      case 'manhua':
        return 'Manhua';
      default:
        return 'All Manga';
    }
  }

  String _typeEyebrow(String type) {
    switch (type) {
      case 'manga':
        return 'Japanese';
      case 'manhwa':
        return 'Korean';
      case 'manhua':
        return 'Chinese';
      default:
        return '';
    }
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
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: KatanaColors.textLight,
            ),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center, style: KatanaType.body),
            const SizedBox(height: 14),
            KatanaButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatest(List<KatanaManga> latest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KatanaSectionHeader(title: 'Latest Updates'),
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
          const KatanaSectionHeader(
            title: 'Hot Manga',
            trailing: Icon(
              Icons.local_fire_department_rounded,
              color: KatanaColors.orange,
              size: 20,
            ),
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
          const KatanaSectionHeader(title: 'Genres'),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
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

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? KatanaColors.accent.withValues(alpha: 0.18)
              : KatanaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? KatanaColors.accent : KatanaColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? KatanaColors.accent : KatanaColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitBold.copyWith(
                color: selected ? KatanaColors.accent : KatanaColors.text,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
