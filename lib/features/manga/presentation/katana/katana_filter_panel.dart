import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import './katana_theme.dart';

/// The Manga Katana filter widget: genre include/exclude toggles,
/// AND/OR mode, minimum chapter count and sort order.
class KatanaFilterPanel extends StatefulWidget {
  final Set<String> include;
  final Set<String> exclude;
  final String genreMode;
  final String chapters;
  final String orderBy;
  final ValueChanged<KatanaFilterState> onApply;

  const KatanaFilterPanel({
    super.key,
    required this.include,
    required this.exclude,
    required this.genreMode,
    required this.chapters,
    required this.orderBy,
    required this.onApply,
  });

  @override
  State<KatanaFilterPanel> createState() => _KatanaFilterPanelState();
}

class KatanaFilterState {
  final Set<String> include;
  final Set<String> exclude;
  final String genreMode;
  final String chapters;
  final String orderBy;

  const KatanaFilterState({
    required this.include,
    required this.exclude,
    required this.genreMode,
    required this.chapters,
    required this.orderBy,
  });
}

class _KatanaFilterPanelState extends State<KatanaFilterPanel> {
  late Set<String> _include;
  late Set<String> _exclude;
  late String _genreMode;
  late String _chapters;
  late String _orderBy;
  List<KatanaGenre> _genres = const [];
  bool _loadingGenres = true;

  @override
  void initState() {
    super.initState();
    _include = Set.of(widget.include);
    _exclude = Set.of(widget.exclude);
    _genreMode = widget.genreMode;
    _chapters = widget.chapters;
    _orderBy = widget.orderBy;
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    final genres = await KatanaService().fetchGenres();
    if (mounted) {
      setState(() {
        _genres = genres;
        _loadingGenres = false;
      });
    }
  }

  void _apply() {
    widget.onApply(KatanaFilterState(
      include: Set.of(_include),
      exclude: Set.of(_exclude),
      genreMode: _genreMode,
      chapters: _chapters,
      orderBy: _orderBy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KatanaSectionHeader(title: 'Filter', trailing: const Icon(
          Icons.filter_list_rounded,
          color: KatanaColors.accent,
          size: 18,
        )),
        const SizedBox(height: 12),
        _label('Genres:'),
        const SizedBox(height: 6),
        if (_loadingGenres)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: KatanaColors.accent),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final genre in _genres)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            genre.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitWhite.copyWith(
                              color: KatanaColors.text,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        _toggleChip('+', 'Include ${genre.name}',
                            _include.contains(genre.slug), () {
                          setState(() {
                            _include.contains(genre.slug)
                                ? _include.remove(genre.slug)
                                : _include.add(genre.slug);
                            _exclude.remove(genre.slug);
                          });
                        }),
                        const SizedBox(width: 4),
                        _toggleChip('−', 'Exclude ${genre.name}',
                            _exclude.contains(genre.slug), () {
                          setState(() {
                            _exclude.contains(genre.slug)
                                ? _exclude.remove(genre.slug)
                                : _exclude.add(genre.slug);
                            _include.remove(genre.slug);
                          });
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        _label('Genre Inclusion mode:'),
        const SizedBox(height: 6),
        Row(
          children: [
            _radio('AND (All Selected Genres)', 'and'),
            const SizedBox(width: 12),
            _radio('OR (Any Selected Genres)', 'or'),
          ],
        ),
        const SizedBox(height: 14),
        _label('Chapters:'),
        const SizedBox(height: 6),
        _dropdown(
          _chapters,
          const [
            ('=1', '=1'),
            ('1', '1+'),
            ('5', '5+'),
            ('10', '10+'),
            ('20', '20+'),
            ('30', '30+'),
            ('50', '50+'),
            ('100', '100+'),
            ('150', '150+'),
            ('200', '200+'),
          ],
          (v) => setState(() => _chapters = v),
        ),
        const SizedBox(height: 14),
        _label('Order by:'),
        const SizedBox(height: 6),
        _dropdown(
          _orderBy,
          const [
            ('latest', 'Latest update'),
            ('new', 'New manga'),
            ('az', 'A-Z'),
            ('numc', 'Number of chapters'),
          ],
          (v) => setState(() => _orderBy = v),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: KatanaButton(
            label: 'Apply filter',
            icon: Icons.check_rounded,
            onTap: _apply,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppTypography.outfitBold.copyWith(
        color: KatanaColors.text,
        fontSize: 12.5,
      ),
    );
  }

  Widget _toggleChip(String symbol, String tooltip, bool active, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? KatanaColors.accent : KatanaColors.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? KatanaColors.accent : KatanaColors.border,
            ),
          ),
          child: Text(
            symbol,
            style: AppTypography.outfitBold.copyWith(
              color: active ? Colors.white : KatanaColors.textMuted,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _radio(String label, String value) {
    final selected = _genreMode == value;
    return GestureDetector(
      onTap: () => setState(() => _genreMode = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            size: 17,
            color: selected ? KatanaColors.accent : KatanaColors.textLight,
          ),
          const SizedBox(width: 5),
          Text(label, style: KatanaType.small),
        ],
      ),
    );
  }

  Widget _dropdown(
    String value,
    List<(String, String)> items,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: KatanaColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KatanaColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: KatanaType.body.copyWith(fontSize: 12.5),
          dropdownColor: KatanaColors.surface,
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: KatanaColors.textMuted),
          items: [
            for (final (v, label) in items)
              DropdownMenuItem(
                value: v,
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: KatanaType.body.copyWith(fontSize: 12.5),
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
