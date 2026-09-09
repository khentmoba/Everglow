import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../features/journal/data/models/journal_entry.dart';
import '../../../../features/journal/data/services/journal_service.dart';

/// Dashboard preview — hero Journal card with letters & memories.
/// Atelier glass styling matching keepsakes cluster.
class JournalPreview extends StatefulWidget {
  final Stream<List<JournalEntry>>? entriesStream;
  const JournalPreview({super.key, this.entriesStream});

  @override
  State<JournalPreview> createState() => _JournalPreviewState();
}

class _JournalPreviewState extends State<JournalPreview> {
  bool _hovered = false;
  StreamSubscription<List<JournalEntry>>? _sub;
  Timer? _retryTimer;
  List<JournalEntry>? _entries;
  Object? _error;
  bool _isLoading = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _sub?.cancel();
    _retryTimer?.cancel();
    final stream = widget.entriesStream ?? JournalService().watchPreview(limit: 12);
    _sub = stream.listen(
      (data) {
        if (!mounted) return;
        _retryCount = 0;
        setState(() {
          _entries = data;
          _error = null;
          _isLoading = false;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        _scheduleSilentRetry(error);
      },
      onDone: () {
        if (!mounted) return;
        if (_isLoading && _entries == null) _scheduleSilentRetry(_error);
      },
    );
  }

  void _scheduleSilentRetry(Object? error) {
    if (!mounted) return;
    if (_retryCount < _maxRetries) {
      _retryCount++;
      _error = error ?? _error;
      _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
        if (mounted) _subscribe();
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = error ?? _error;
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
      _retryCount = 0;
    });
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    const hue = AppColors.softLavender;
    final entries = _entries;

    // Error state
    if (!_isLoading && (_error != null || entries == null)) {
      return _buildCardShell(
        hue: hue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              hue: hue,
              title: 'Our Journal',
              subtitle: 'Could not load journal',
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: hue.withValues(alpha: 0.08),
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: hue.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 16, color: hue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${firestoreErrorHint(_error)} — tap to retry.',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 11,
                          color: AppColors.petalWhite.withValues(alpha: 0.70),
                        ),
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

    // Loading state
    if (entries == null) {
      return _buildCardShell(
        hue: hue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              hue: hue,
              title: 'Our Journal',
              subtitle: 'Loading our memories…',
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: AppRadius.radiusFull,
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: hue.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(hue),
              ),
            ),
            const SizedBox(height: 12),
            _buildSkeletonTile(hue),
            const SizedBox(height: 7),
            _buildSkeletonTile(hue),
          ],
        ),
      );
    }

    final count = entries.length;
    final pinned = entries.where((e) => e.isPinned).length;
    final recent = entries.take(3).toList();
    final totalWords = entries.fold<int>(0, (sum, e) => sum + e.wordCount);

    final subtitle = count == 0
        ? 'No entries yet — write your first memory'
        : '$count ${count == 1 ? 'entry' : 'entries'}${pinned > 0 ? ' • $pinned pinned' : ''}';

    return _buildCardShell(
      hue: hue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            hue: hue,
            title: 'Our Journal',
            subtitle: subtitle,
          ),
          const SizedBox(height: 12),
          _buildMetricTracker(
            hue: hue,
            count: count,
            totalWords: totalWords,
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.petalWhite.withValues(alpha: 0.07),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const _EmptyJournalState(hue: hue)
          else
            ...recent.map((entry) => _JournalItemRow(entry: entry, hue: hue)),
          const SizedBox(height: 6),
          _buildFooterAffordance(hue),
        ],
      ),
    );
  }

  Widget _buildCardShell({required Color hue, required Widget child}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.push('/journal'),
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.medium),
          curve: AppMotion.easeOutStrong,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0),
          decoration: BoxDecoration(
            color: AppColors.inkDeep.withValues(alpha: 0.42),
            borderRadius: AppRadius.radiusXl,
            border: Border.all(
              color: _hovered
                  ? hue.withValues(alpha: 0.38)
                  : AppColors.petalWhite.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: hue.withValues(alpha: _hovered ? 0.12 : 0.03),
                blurRadius: 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        hue.withValues(alpha: _hovered ? 0.55 : 0.30),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader({
    required Color hue,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        _IconChip(icon: Icons.auto_stories_rounded, hue: hue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.cormorantBold.copyWith(
                  fontSize: 20,
                  height: 1.1,
                  color: AppColors.petalWhite,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.petalWhite.withValues(alpha: 0.50),
                ),
              ),
            ],
          ),
        ),
        _ActionChevron(hue: hue, hovered: _hovered),
      ],
    );
  }

  Widget _buildMetricTracker({
    required Color hue,
    required int count,
    required int totalWords,
  }) {
    return Row(
      children: [
        // Mini circular quill icon badge
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hue.withValues(alpha: 0.10),
            border: Border.all(
              color: hue.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.edit_note_rounded,
              size: 18,
              color: hue,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Linear indicator & stats
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.radiusFull,
                child: LinearProgressIndicator(
                  value: count > 0 ? 1.0 : 0.0,
                  minHeight: 4,
                  backgroundColor: hue.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(hue.withValues(alpha: 0.85)),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      count == 0
                          ? 'Waiting for our words ✨'
                          : '$count ${count == 1 ? 'memory' : 'memories'} penned',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.petalWhite.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    totalWords > 0 ? '$totalWords words shared' : 'Quiet letters',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: hue.withValues(alpha: 0.90),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterAffordance(Color hue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Read our journal',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: hue.withValues(alpha: _hovered ? 0.95 : 0.70),
          ),
        ),
        const SizedBox(width: 4),
        AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          transform: Matrix4.identity()
            ..translateByDouble(_hovered ? 2.0 : 0.0, 0.0, 0.0, 1.0),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: hue.withValues(alpha: _hovered ? 0.95 : 0.70),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonTile(Color hue) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.petalWhite.withValues(alpha: 0.03),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.05)),
      ),
    );
  }
}

class _JournalItemRow extends StatefulWidget {
  final JournalEntry entry;
  final Color hue;

  const _JournalItemRow({required this.entry, required this.hue});

  @override
  State<_JournalItemRow> createState() => _JournalItemRowState();
}

class _JournalItemRowState extends State<_JournalItemRow> {
  bool _hovered = false;

  Color _categoryColor(JournalCategory c) {
    switch (c) {
      case JournalCategory.daily:
        return AppColors.softLavender;
      case JournalCategory.gratitude:
        return AppColors.blushGold;
      case JournalCategory.memory:
        return AppColors.auroraTeal;
      case JournalCategory.letter:
        return AppColors.deepRose;
      case JournalCategory.dream:
        return AppColors.auroraLilac;
      case JournalCategory.idea:
        return AppColors.warmAmber;
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0 && now.day == d.day) return 'Today';
    if (diff <= 1 && now.day - d.day == 1) return 'Yesterday';
    if (diff < 7 && diff > 0) return '${diff}d ago';
    if (d.year == now.year) return DateFormat.MMMd().format(d);
    return DateFormat.yMMMd().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final catColor = _categoryColor(entry.category);

    final cleanAuthor = entry.author.toLowerCase().trim();
    final isClair = cleanAuthor.contains('clair');
    final isKhent = cleanAuthor.contains('khent');
    final authorLabel = isClair
        ? 'by Clair'
        : isKhent
            ? 'by Khent'
            : (entry.author.isNotEmpty ? 'by ${entry.author}' : null);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.orZero(AppMotion.fast),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.hue.withValues(alpha: 0.08)
              : AppColors.petalWhite.withValues(alpha: 0.025),
          borderRadius: AppRadius.radiusSm,
          border: Border.all(
            color: _hovered
                ? widget.hue.withValues(alpha: 0.28)
                : AppColors.petalWhite.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.radiusXs,
                border: Border.all(
                  color: catColor.withValues(alpha: 0.22),
                ),
              ),
              child: Center(
                child: Text(
                  entry.category.emoji,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title.trim().isEmpty
                              ? 'Untitled memory'
                              : entry.title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.petalWhite.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      if (entry.isPinned) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.push_pin_rounded,
                          size: 11,
                          color: AppColors.auroraGold,
                        ),
                      ],
                      if (entry.isLocked) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: AppColors.warmAmber,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _formatDate(entry.createdAt),
                          style: TextStyle(
                            color: AppColors.petalWhite.withValues(alpha: 0.45),
                          ),
                        ),
                        if (authorLabel != null) ...[
                          TextSpan(
                            text: '  •  ',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.petalWhite.withValues(alpha: 0.25),
                            ),
                          ),
                          TextSpan(
                            text: authorLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isClair
                                  ? AppColors.roseQuartz
                                  : isKhent
                                      ? AppColors.auroraTeal
                                      : AppColors.petalWhite.withValues(alpha: 0.50),
                            ),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.petalWhite.withValues(alpha: 0.06),
                borderRadius: AppRadius.radiusFull,
                border: Border.all(
                  color: AppColors.petalWhite.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.mood != null) ...[
                    Text(
                      entry.mood!.emoji,
                      style: const TextStyle(fontSize: 10),
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    '${entry.wordCount}w',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.petalWhite.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyJournalState extends StatelessWidget {
  final Color hue;
  const _EmptyJournalState({required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.05),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded, size: 18, color: hue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Write our first memory together',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.petalWhite.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Capture a date, a fight, a laugh — keep it forever.',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10.5,
                    color: AppColors.petalWhite.withValues(alpha: 0.50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final Color hue;

  const _IconChip({required this.icon, required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hue.withValues(alpha: 0.22),
            hue.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: hue, size: 19),
      ),
    );
  }
}

class _ActionChevron extends StatelessWidget {
  final Color hue;
  final bool hovered;

  const _ActionChevron({required this.hue, this.hovered = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.orZero(AppMotion.fast),
      width: 28,
      height: 28,
      transform: Matrix4.identity()
        ..translateByDouble(hovered ? 2.0 : 0.0, 0.0, 0.0, 1.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hue.withValues(alpha: hovered ? 0.18 : 0.08),
        border: Border.all(color: hue.withValues(alpha: hovered ? 0.45 : 0.25)),
      ),
      child: Center(
        child: Icon(
          Icons.arrow_forward_rounded,
          color: hue.withValues(alpha: hovered ? 1.0 : 0.85),
          size: 14,
        ),
      ),
    );
  }
}
