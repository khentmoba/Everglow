import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';

import '../../data/services/ai_memory_repo.dart';
import '../../domain/memory/memory_fact.dart';

/// Mochi's Memory Book — a co-owned review surface for everything she
/// remembers. Search, pin, delete, and add facts; on-this-day memories
/// get their own shelf so anniversaries surface naturally.
class MemoryBookScreen extends StatefulWidget {
  const MemoryBookScreen({super.key});

  @override
  State<MemoryBookScreen> createState() => _MemoryBookScreenState();
}

class _MemoryBookScreenState extends State<MemoryBookScreen> {
  final AIMemoryRepository _repo = AIMemoryRepository();
  final TextEditingController _searchController = TextEditingController();

  List<MemoryFact> _facts = [];
  bool _loading = true;
  String _query = '';
  String? _category;

  static const _categories = [
    null,
    'fact',
    'preference',
    'dislike',
    'goal',
    'date',
    'habit',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _repo.load();
    if (!mounted) return;
    setState(() {
      _facts = _repo.facts;
      _loading = false;
    });
  }

  List<MemoryFact> get _visibleFacts {
    var facts = _facts;
    if (_category != null) {
      facts = facts.where((f) => f.category == _category).toList();
    }
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      facts = facts.where((f) {
        final haystack =
            '${f.fact} ${f.subject ?? ''} '
                    '${f.object ?? ''} ${f.category}'
                .toLowerCase();
        return haystack.contains(query);
      }).toList();
    }
    facts.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final aDate = a.createdAt ?? DateTime(2000);
      final bDate = b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return facts;
  }

  Future<void> _addFact() async {
    final result = await showDialog<MemoryFact>(
      context: context,
      builder: (context) => const _AddMemoryDialog(),
    );
    if (result == null || !mounted) return;
    await _repo.saveStructured(
      fact: result.fact,
      category: result.category,
      subject: result.subject,
      relation: result.relation,
      object: result.object,
      occurredAt: result.occurredAt,
    );
    await _load();
  }

  Future<void> _deleteFact(MemoryFact fact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.velvet,
        shape: AppRadius.shapeX2,
        title: const Text(
          'Forget this memory?',
          style: TextStyle(color: AppColors.petalWhite),
        ),
        content: Text(
          'Mochi will no longer remember: ${fact.fact}',
          style: AppTypography.outfitMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Forget',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _repo.delete(fact.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final onThisDay = _facts
        .where((f) => f.isOnThisDay(DateTime.now()))
        .toList();
    return Scaffold(
      backgroundColor: AppColors.twilight,
      body: Stack(
        children: [
          const EverglowBackground(
            showPetals: true,
            glows: [
              RadialGlow(
                color: AppColors.softLavender,
                alignment: Alignment(-0.7, -0.8),
                size: 0.7,
                opacity: 0.12,
              ),
              RadialGlow(
                color: AppColors.auroraRose,
                alignment: Alignment(0.85, 0.9),
                size: 0.6,
                opacity: 0.10,
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(
                  title: "Mochi's Memory Book",
                  subtitle: 'what Mochi remembers about you',
                  icon: Icons.menu_book_rounded,
                  hue: AppColors.softLavender,
                  actions: [
                    IconButton(
                      tooltip: 'Add a memory',
                      onPressed: _addFact,
                      icon: const Icon(
                        Icons.add_rounded,
                        color: AppColors.softLavender,
                      ),
                    ),
                  ],
                ),
                _buildSearchBar(),
                _buildCategoryChips(),
                if (onThisDay.isNotEmpty) _buildOnThisDayBanner(onThisDay),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        style: AppTypography.outfitWhite,
        decoration: InputDecoration(
          hintText: 'Search memories...',
          hintStyle: AppTypography.outfitMuted,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.softLavender,
          ),
          filled: true,
          fillColor: AppColors.surfaceGlass,
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusFull,
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusFull,
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusFull,
            borderSide: BorderSide(
              color: AppColors.softLavender.withValues(alpha: 0.7),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final label = category ?? 'All';
          final selected = _category == category;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => setState(() => _category = category),
            labelStyle: AppTypography.outfitWhite.copyWith(fontSize: 12),
            selectedColor: AppColors.softLavender.withValues(alpha: 0.25),
            backgroundColor: AppColors.surfaceGlass,
            side: BorderSide(
              color: selected ? AppColors.softLavender : AppColors.border,
            ),
            shape: AppRadius.shapeXl,
          );
        },
      ),
    );
  }

  Widget _buildOnThisDayBanner(List<MemoryFact> facts) {
    final first = facts.first;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.auroraGold.withValues(alpha: 0.18),
            AppColors.deepRose.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.auroraGold.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          const Text('📌', style: TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'On This Day',
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 13,
                    color: AppColors.auroraGold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  first.fact,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitWhite.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          if (facts.length > 1)
            Text(
              '+${facts.length - 1}',
              style: AppTypography.outfitBold.copyWith(
                color: AppColors.auroraGold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.softLavender),
      );
    }
    final facts = _visibleFacts;
    if (facts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x2),
          child: Text(
            'No memories here yet. Tell Mochi something worth keeping.',
            textAlign: TextAlign.center,
            style: AppTypography.outfitMedium,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.x2,
      ),
      itemCount: facts.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _MemoryCard(
        fact: facts[index],
        onPin: () async {
          await _repo.setPinned(facts[index].id, !facts[index].pinned);
          await _load();
        },
        onDelete: () => _deleteFact(facts[index]),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryFact fact;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const _MemoryCard({
    required this.fact,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final occurred = fact.occurredAt;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: fact.pinned
              ? AppColors.auroraGold.withValues(alpha: 0.6)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fact.pinned
                  ? AppColors.auroraGold.withValues(alpha: 0.18)
                  : AppColors.softLavender.withValues(alpha: 0.14),
            ),
            child: Icon(
              fact.pinned ? Icons.push_pin_rounded : Icons.spa_outlined,
              size: 17,
              color: fact.pinned
                  ? AppColors.auroraGold
                  : AppColors.softLavender,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fact.fact,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _Tag(label: fact.category),
                    if (fact.subject != null) _Tag(label: fact.subject!),
                    if (fact.object != null) _Tag(label: fact.object!),
                    if (occurred != null)
                      _Tag(label: '${occurred.month}/${occurred.day}'),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: fact.pinned ? 'Unpin' : 'Pin',
            onPressed: onPin,
            icon: Icon(
              fact.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 18,
              color: fact.pinned ? AppColors.auroraGold : AppColors.textMuted,
            ),
          ),
          IconButton(
            tooltip: 'Forget',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.softLavender.withValues(alpha: 0.10),
        borderRadius: AppRadius.radiusXs,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTypography.outfitMedium.copyWith(fontSize: 10),
      ),
    );
  }
}

class _AddMemoryDialog extends StatefulWidget {
  const _AddMemoryDialog();

  @override
  State<_AddMemoryDialog> createState() => _AddMemoryDialogState();
}

class _AddMemoryDialogState extends State<_AddMemoryDialog> {
  final TextEditingController _factController = TextEditingController();
  String _category = 'fact';
  DateTime? _occurredAt;

  @override
  void initState() {
    super.initState();
    _factController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _factController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.velvet,
      shape: AppRadius.shapeX2,
      title: const Text(
        'New memory',
        style: TextStyle(color: AppColors.petalWhite),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _factController,
            autofocus: true,
            maxLines: 3,
            style: AppTypography.outfitWhite,
            decoration: InputDecoration(
              hintText: 'e.g. Khent prefers black coffee',
              hintStyle: TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _category,
            dropdownColor: AppColors.velvet,
            style: AppTypography.outfitWhite,
            items: const [
              DropdownMenuItem(value: 'fact', child: Text('Fact')),
              DropdownMenuItem(value: 'preference', child: Text('Preference')),
              DropdownMenuItem(value: 'dislike', child: Text('Dislike')),
              DropdownMenuItem(value: 'goal', child: Text('Goal')),
              DropdownMenuItem(value: 'date', child: Text('Date')),
              DropdownMenuItem(value: 'habit', child: Text('Habit')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _occurredAt ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _occurredAt = picked);
            },
            icon: const Icon(
              Icons.event_rounded,
              color: AppColors.softLavender,
            ),
            label: Text(
              _occurredAt == null
                  ? 'Add a date (optional)'
                  : '${_occurredAt!.month}/${_occurredAt!.day}/${_occurredAt!.year}',
              style: AppTypography.outfitMedium,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _factController.text.trim().isEmpty
              ? null
              : () {
                  final parser = const FactStructureParser();
                  final inferred = parser.parse(_factController.text.trim());
                  Navigator.pop(
                    context,
                    MemoryFact(
                      fact: _factController.text.trim(),
                      category: _category,
                      subject: inferred.$1,
                      relation: inferred.$2,
                      object: inferred.$3,
                      occurredAt: _occurredAt,
                    ),
                  );
                },
          child: const Text('Remember'),
        ),
      ],
    );
  }
}
