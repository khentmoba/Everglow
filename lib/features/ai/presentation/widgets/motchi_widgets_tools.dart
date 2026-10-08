part of 'motchi_screen.dart';

/// Active actions wrap so every running tool remains visible on a phone.
class _LiveToolStrip extends StatelessWidget {
  final AIService ai;
  const _LiveToolStrip({required this.ai});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.orZero(
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.medium,
      ),
      curve: AppMotion.easeOutStrong,
      alignment: Alignment.topLeft,
      child: ValueListenableBuilder<List<String>>(
        valueListenable: ai.activeToolsNotifier,
        builder: (context, tools, _) {
          if (tools.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tool in tools)
                  _ToolStatusChip(key: ValueKey(tool), status: tool),
              ],
            ),
          );
        },
      ),
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
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceAmbientMotion(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _toolAccent(widget.status);
    return Semantics(
      label: _formatToolStatus(widget.status),
      liveRegion: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glassSoft,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
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
            Icon(_toolIcon(widget.status), size: 16, color: accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _formatToolStatus(widget.status),
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 13,
                  color: AppColors.textHigh,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sources remain readable and keyboard accessible without sideways scrolling.
class WebSourcesCard extends StatelessWidget {
  final List<Map<String, String>> sources;
  const WebSourcesCard({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    return Material(
      color: AppColors.glassSoft,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusMd,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.travel_explore_rounded,
                  size: 20,
                  color: AppColors.softLavender,
                ),
                const SizedBox(width: 8),
                Text('Sources', style: AppTypography.bodyMedium()),
                const SizedBox(width: 8),
                Text(
                  '${sources.length}',
                  style: AppTypography.bodySmall().copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          for (final source in sources) _WebSourceTile(source: source),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _WebSourceTile extends StatelessWidget {
  final Map<String, String> source;
  const _WebSourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    final url = source['url'] ?? '';
    final uri = Uri.tryParse(url.trim());
    final canOpen =
        uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty;
    final host = (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
    final site = source['site']?.trim() ?? '';
    final subtitle = host.isNotEmpty ? host : site;
    final title = source['title']?.trim() ?? '';
    return Semantics(
      link: canOpen,
      child: InkWell(
        onTap: canOpen ? () => _openWebSource(url) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty
                            ? (subtitle.isEmpty ? 'Source' : subtitle)
                            : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall().copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHigh,
                          height: 1.4,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall().copyWith(
                            color: AppColors.textMedium,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canOpen) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: AppColors.softLavender,
                  ),
                ],
              ],
            ),
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
