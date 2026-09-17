part of 'motchi_screen.dart';

/// Compact pill showing which agent action Motchi is performing.
class _ToolStatusChip extends StatelessWidget {
  final String status;

  const _ToolStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final accent = _toolAccent(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: accent.withValues(alpha: 0.32), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Icon(_toolIcon(status), size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            _formatToolStatus(status),
            style: AppTypography.bodySmall().copyWith(
              fontSize: 11.5,
              color: AppColors.petalWhite,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick-reply chips shown above the composer for one-tap follow-ups.
class _QuickReplyChips extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final bool centered;
  final bool enabled;

  const _QuickReplyChips({
    required this.onSelect,
    this.centered = false,
    this.enabled = true,
  });

  static List<(String, String)> _getContextualChips() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      // Morning (5am - 12pm)
      return const [
        (
          'Morning recap ☀️',
          'Good morning Motchi! Give us our morning digest and what is on for today.',
        ),
        ('Log my mood 💭', 'I want to log my mood for today'),
        (
          'Couple question 💖',
          'Ask us a sweet couple question to start our day together!',
        ),
        (
          'What to watch tonight? 🎬',
          'What should we watch tonight from our watchlist?',
        ),
        (
          'Quiz us ✍️',
          'Quiz us! Make a fun 5-question quiz for us with A-D options.',
        ),
        ('Save to Starlight ✨', 'Save this note to our Starlight Jar: '),
        ('Add calendar 📅', 'Add a calendar event for tomorrow at 7pm'),
      ];
    } else if (hour >= 12 && hour < 17) {
      // Afternoon (12pm - 5pm)
      return const [
        (
          'Check in on us 💌',
          'How are we doing today? Any sweet updates or notes?',
        ),
        (
          'Quiz us ✍️',
          'Quiz us! Make a fun 5-question quiz for us with A-D options.',
        ),
        (
          'Flashcards 💡',
          'Make us flashcards — 8 cards on something fun for us to learn together.',
        ),
        (
          'Build a game 🎮',
          'Make us a little game we can play right here — like tic-tac-toe!',
        ),
        ('Log my mood 💭', 'I want to log my mood'),
        ('Plan a date 🥂', 'Plan a cozy date night for us'),
        ('What should we watch? 🎬', 'What should we watch tonight?'),
      ];
    } else {
      // Evening / Night (5pm - 5am)
      return const [
        (
          'What to watch tonight? 🎬',
          'What should we watch tonight from our watchlist?',
        ),
        (
          'Today\'s recap 🌙',
          'Give us today\'s recap of what happened in Everglow today.',
        ),
        ('Save to Starlight ✨', 'Save this note to our Starlight Jar: '),
        ('Plan a date 🥂', 'Plan a cozy date night for us'),
        (
          'Quiz us ✍️',
          'Quiz us! Make a fun 5-question quiz for us with A-D options.',
        ),
        ('Journal ✍️', 'Create a journal entry about our day together'),
        ('Bucket dream ✨', 'Add something to our bucket list'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = _getContextualChips();
    final inner = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: centered ? 24 : 12,
        vertical: 8,
      ),
      child: Row(
        children: chips.map((e) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _QuickPill(
              label: e.$1,
              onTap: enabled ? () => onSelect(e.$2) : null,
            ),
          );
        }).toList(),
      ),
    );
    if (!centered) return inner;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: inner,
      ),
    );
  }
}

class _QuickPill extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _QuickPill({required this.label, this.onTap});
  @override
  State<_QuickPill> createState() => _QuickPillState();
}

class _QuickPillState extends State<_QuickPill> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onTap!();
                  }
                : null,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _hover && enabled
                        ? AppColors.velvet.withValues(alpha: 0.95)
                        : AppColors.inkDeep.withValues(alpha: 0.85),
                    _hover && enabled
                        ? AppColors.plum.withValues(alpha: 0.75)
                        : AppColors.velvet.withValues(alpha: 0.65),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _hover && enabled
                      ? AppColors.blushGold.withValues(alpha: 0.40)
                      : AppColors.moonlight.withValues(alpha: 0.16),
                  width: 0.9,
                ),
                boxShadow: _hover && enabled
                    ? [
                        BoxShadow(
                          color: AppColors.blushGold.withValues(alpha: 0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                widget.label,
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _hover && enabled
                      ? AppColors.petalWhite
                      : AppColors.textMedium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline cards for tool results — rendered below the streaming bubble
class _ToolResultCards extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final bool centered;
  const _ToolResultCards({required this.results, this.centered = false});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: results.map((r) {
          final tool = r['tool'] as String? ?? 'tool';
          // Web tools render tappable source rows instead of the generic
          // card — Clair can open what Motchi actually read.
          if (tool == 'web_search' || tool == 'read_web_page') {
            final webSources = AIService.webSourcesFromToolResults([r]);
            if (webSources.isNotEmpty) {
              return _WebSourcesCard(
                sources: webSources,
                query: tool == 'web_search' ? r['query'] as String? : null,
              );
            }
            // Empty/error falls through to the generic card below.
          }
          final success = r['success'] == true;
          final needsConfirm = r['needs_confirmation'] == true;
          final title =
              r['title'] as String? ??
              r['fact'] as String? ??
              r['id'] as String? ??
              '';
          final msg = r['message'] as String? ?? '';
          Color accent = _toolAccent(tool);
          IconData icon = _toolIcon(tool);
          String label = _formatToolStatus(tool);
          if (needsConfirm) {
            label = 'Needs confirmation';
          } else if (success) {
            label = '$label ✓';
          } else if (r['error'] != null) {
            label = 'Failed';
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.inkDeep.withValues(alpha: 0.90),
                  AppColors.velvet.withValues(alpha: 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: 0.28),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.30),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(icon, size: 15, color: accent),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.bodySmall().copyWith(
                          fontSize: 10.5,
                          color: accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: AppTypography.bodySmall().copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.petalWhite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (msg.isNotEmpty && !needsConfirm)
                        Text(
                          msg,
                          style: AppTypography.bodySmall().copyWith(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (needsConfirm && msg.isNotEmpty)
                        Text(
                          msg,
                          style: AppTypography.bodySmall().copyWith(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Tappable web sources — shown live while Motchi searches and persisted
/// under her finished reply. Same card language as [_ToolResultCards].
class _WebSourcesCard extends StatelessWidget {
  final List<Map<String, String>> sources; // {title, url, site}
  final String? query;
  const _WebSourcesCard({required this.sources, this.query});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    const accent = AppColors.auroraTeal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.inkDeep.withValues(alpha: 0.90),
            AppColors.velvet.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                'Sources',
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 10.5,
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              if (query != null && query!.trim().isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '· ${query!.trim()}',
                    style: AppTypography.bodySmall().copyWith(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < sources.length; i++)
            _WebSourceRow(
              index: i + 1,
              title: sources[i]['title'] ?? '',
              url: sources[i]['url'] ?? '',
              site: sources[i]['site'] ?? '',
            ),
        ],
      ),
    );
  }
}

class _WebSourceRow extends StatelessWidget {
  final int index;
  final String title;
  final String url;
  final String site;
  const _WebSourceRow({
    required this.index,
    required this.title,
    required this.url,
    required this.site,
  });

  @override
  Widget build(BuildContext context) {
    final label = title.isNotEmpty ? title : (site.isNotEmpty ? site : url);
    final sub = site.isNotEmpty && title.isNotEmpty ? site : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _openWebSource(url);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.auroraTeal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$index',
                  style: AppTypography.bodySmall().copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.auroraTeal,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodySmall().copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.petalWhite,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        style: AppTypography.bodySmall().copyWith(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a source link outside Everglow. Failures stay silent — a dead
/// link is not worth an error banner in the middle of Clair's chat.
Future<void> _openWebSource(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Animated placeholder shown while Motchi is thinking before any text or
/// tool activity has streamed in.
