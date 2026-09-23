part of 'motchi_screen.dart';

/// Live horizontal strip of what Motchi is doing RIGHT NOW.
///
/// Each chip vanishes the moment its tool finishes, so the strip never
/// stacks up or pushes the chat down — concurrent tools simply sit side
/// by side and the strip follows the newest one.
class _LiveToolStrip extends StatefulWidget {
  final AIService ai;
  const _LiveToolStrip({required this.ai});

  @override
  State<_LiveToolStrip> createState() => _LiveToolStripState();
}

class _LiveToolStripState extends State<_LiveToolStrip> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _followNewest() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if ((_scroll.offset - max).abs() > 1) {
      _scroll.animateTo(
        max,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: widget.ai.activeToolsNotifier,
      builder: (context, tools, _) {
        if (tools.isEmpty) return const SizedBox.shrink();
        WidgetsBinding.instance.addPostFrameCallback((_) => _followNewest());
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tools.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: _DelayedFadeIn(
                      key: ValueKey(tools[i]),
                      child: _ToolStatusChip(status: tools[i]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact live pill showing one agent action Motchi is performing. The
/// dot pulses while the tool runs; [_LiveToolStrip] removes the pill the
/// moment the tool finishes.
class _ToolStatusChip extends StatefulWidget {
  final String status;

  const _ToolStatusChip({required this.status});

  @override
  State<_ToolStatusChip> createState() => _ToolStatusChipState();
}

class _ToolStatusChipState extends State<_ToolStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _toolAccent(widget.status);
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
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Opacity(
              opacity: 0.45 + 0.55 * _c.value,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Icon(_toolIcon(widget.status), size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            _formatToolStatus(widget.status),
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
    if (!enabled) return const SizedBox.shrink();
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

/// Tappable web sources — persisted under her finished reply so Clair
/// can open what Motchi actually read.
class _WebSourcesCard extends StatelessWidget {
  final List<Map<String, String>> sources; // {title, url, site}
  const _WebSourcesCard({required this.sources});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    const accent = AppColors.auroraTeal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1),
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
                'SOURCES · ${sources.length}',
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 10.5,
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
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
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
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
                        fontSize: 13,
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
                          fontSize: 11.5,
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
