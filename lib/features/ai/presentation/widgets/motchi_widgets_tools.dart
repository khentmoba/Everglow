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
                    child: _ToolStatusChip(
                      key: ValueKey(tools[i]),
                      status: tools[i],
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

  const _ToolStatusChip({super.key, required this.status});

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

/// Tappable web sources saved with a reply.
class WebSourcesCard extends StatelessWidget {
  final List<Map<String, String>> sources; // {title, url, site}
  const WebSourcesCard({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    const accent = AppColors.auroraTeal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.inkDeep.withValues(alpha: 0.90),
            AppColors.velvet.withValues(alpha: 0.70),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  size: 12,
                  color: accent,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'MOTCHI\'S DISCOVERIES',
                style: AppTypography.labelSmall().copyWith(
                  fontSize: 10,
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sources.length}',
                  style: AppTypography.labelSmall().copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sources.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return _WebSourceTile(
                  index: i + 1,
                  title: sources[i]['title'] ?? '',
                  url: sources[i]['url'] ?? '',
                  site: sources[i]['site'] ?? '',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSourceTile extends StatefulWidget {
  final int index;
  final String title;
  final String url;
  final String site;

  const _WebSourceTile({
    required this.index,
    required this.title,
    required this.url,
    required this.site,
  });

  @override
  State<_WebSourceTile> createState() => _WebSourceTileState();
}

class _WebSourceTileState extends State<_WebSourceTile> {
  bool _hover = false;

  String _cleanHost(String site, String url) {
    var s = site.trim();
    if (s.isEmpty) {
      s = Uri.tryParse(url)?.host ?? '';
    }
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.replaceFirst(RegExp(r'^www\.'), '');
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.isEmpty ? 'source' : s;
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.auroraTeal;
    final host = _cleanHost(widget.site, widget.url);
    final displayTitle = widget.title.isNotEmpty ? widget.title : host;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _openWebSource(widget.url);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: _hover
                ? AppColors.inkDeep.withValues(alpha: 0.95)
                : AppColors.velvet.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _hover
                  ? accent.withValues(alpha: 0.50)
                  : accent.withValues(alpha: 0.20),
              width: 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${widget.index}',
                      style: AppTypography.labelSmall().copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      host,
                      style: AppTypography.bodySmall().copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: accent.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 13,
                    color: _hover ? accent : AppColors.textMuted,
                  ),
                ],
              ),
              Text(
                displayTitle,
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.petalWhite,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
