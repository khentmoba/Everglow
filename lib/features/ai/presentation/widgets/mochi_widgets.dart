part of 'mochi_screen.dart';

class _MochiHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSidebarToggle;
  final VoidCallback onNewChat;
  final bool deepThink;
  final VoidCallback onToggleDeepThink;
  final bool isDesktop;
  final bool sidebarOpen;

  const _MochiHeader({
    required this.onBack,
    required this.onSidebarToggle,
    required this.onNewChat,
    required this.deepThink,
    required this.onToggleDeepThink,
    this.isDesktop = false,
    this.sidebarOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    final showNav = isDesktop || MediaQuery.sizeOf(context).width >= 520;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 18 : 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isDesktop
            ? AppColors.twilight.withValues(alpha: 0.7)
            : Colors.transparent,
        border: isDesktop
            ? Border(
                bottom: BorderSide(
                  color: AppColors.blushGold.withValues(alpha: 0.06),
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onSidebarToggle,
            icon: Icon(
              sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            tooltip: sidebarOpen ? 'Close history' : 'History',
          ),
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
            tooltip: 'Back',
          ),
          const SizedBox(width: 2),
          ClipRRect(
            borderRadius: AppRadius.radiusSm,
            child: Image.asset(
              'assets/images/mochi_avatar.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mochi',
                style: AppTypography.titleLarge().copyWith(
                  fontSize: 18,
                  height: 1.0,
                ),
              ),
              if (isDesktop)
                Text(
                  'Your cat who knows everything about you two',
                  style: AppTypography.bodySmall().copyWith(
                    color: AppColors.textDisabled,
                    fontSize: 11,
                    height: 1.0,
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (showNav) ...[
            Tooltip(
              message: 'Memory Book',
              child: InkWell(
                onTap: () => context.push('/mochi-memory'),
                borderRadius: AppRadius.radiusSm,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Memory Trivia',
              child: InkWell(
                onTap: () => context.push('/mochi-trivia'),
                borderRadius: AppRadius.radiusSm,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.quiz_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Mochi Today',
              child: InkWell(
                onTap: () => context.push('/mochi-today'),
                borderRadius: AppRadius.radiusSm,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.wb_twilight_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(width: 1, height: 20, color: AppColors.border),
            const SizedBox(width: 4),
          ],
          Tooltip(
            message: 'New chat',
            child: InkWell(
              onTap: onNewChat,
              borderRadius: AppRadius.radiusSm,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
          Tooltip(
            message: deepThink ? 'Deep thinking: on' : 'Deep thinking: off',
            child: InkWell(
              onTap: onToggleDeepThink,
              borderRadius: AppRadius.radiusSm,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: deepThink
                    ? BoxDecoration(
                        color: AppColors.blushGold.withValues(alpha: 0.14),
                        borderRadius: AppRadius.radiusSm,
                        border: Border.all(
                          color: AppColors.blushGold.withValues(alpha: 0.25),
                        ),
                      )
                    : null,
                child: Icon(
                  deepThink
                      ? Icons.psychology_rounded
                      : Icons.psychology_outlined,
                  color: deepThink ? AppColors.blushGold : AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
          if (!isDesktop)
            IconButton(
              onPressed: onSidebarToggle,
              icon: Icon(
                sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              tooltip: sidebarOpen ? 'Close history' : 'History',
            ),
        ],
      ),
    );
  }
}

// ─── Empty state with greeting & suggested actions ───────────────

class _GreetingEmptyState extends StatelessWidget {
  final void Function(String) onTap;
  final bool centered;
  const _GreetingEmptyState({required this.onTap, this.centered = false});

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: centered ? 48 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DelayedFadeIn(
            delay: const Duration(milliseconds: 0),
            child: Text(
              'Ask Mochi anything',
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge().copyWith(
                fontSize: centered ? 30 : 26,
                color: AppColors.textHigh,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DelayedFadeIn(
            delay: const Duration(milliseconds: 150),
            child: Text(
              'Your cat who knows everything about you two.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall().copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 36),
          _SuggestedGrid(onTap: onTap, centered: centered),
        ],
      ),
    );

    if (!centered) return Center(child: content);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: content,
      ),
    );
  }
}

class _SuggestedGrid extends StatelessWidget {
  final void Function(String) onTap;
  final bool centered;
  const _SuggestedGrid({required this.onTap, this.centered = false});

  static const _suggestions = [
    _Suggestion('Add a movie to our watchlist', Icons.movie_filter_outlined),
    _Suggestion(
      'Save a note to the Starlight Jar',
      Icons.auto_awesome_outlined,
    ),
    _Suggestion('Plan a date for us', Icons.calendar_month_outlined),
    _Suggestion('How are we doing today?', Icons.favorite_outline_rounded),
    _Suggestion(
      'Mochi Today',
      Icons.wb_twilight_rounded,
      route: '/mochi-today',
    ),
    _Suggestion('Memory Trivia', Icons.quiz_rounded, route: '/mochi-trivia'),
    _Suggestion('Memory Book', Icons.menu_book_rounded, route: '/mochi-memory'),
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = centered && w >= 900 ? 3 : 2;
    const spacing = 10.0;
    final aspect = centered ? 2.0 : 1.9;
    // Eager Wrap layout instead of a lazy sliver grid: every template card
    // is laid out and painted on the first frame. A shrink-wrapped
    // GridView.builder inside this nested scrollable left cards unpainted
    // (stuck at the entrance-animation's zero opacity) until a hover forced
    // a repaint — then they vanished again on mouse-leave.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final itemWidth = (maxW - spacing * (cols - 1)) / cols;
        final itemHeight = itemWidth / aspect;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < _suggestions.length; i++)
              SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _DelayedFadeIn(
                  delay: Duration(milliseconds: 200 + i * 80),
                  child: _SuggestionCard(
                    suggestion: _suggestions[i],
                    onTap: onTap,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final _Suggestion suggestion;
  final void Function(String) onTap;
  const _SuggestionCard({required this.suggestion, required this.onTap});

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          final route = widget.suggestion.route;
          if (route != null) {
            context.push(route);
          } else {
            widget.onTap(widget.suggestion.text);
          }
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.easeOutStrong,
          padding: const EdgeInsets.all(14),
          transform: Matrix4.identity()
            ..translateByDouble(0, _hover ? -2.0 : 0.0, 0, 0),
          decoration: BoxDecoration(
            color: _hover
                ? AppColors.moonlight.withValues(alpha: 0.16)
                : AppColors.surfaceGlass,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: _hover
                  ? AppColors.blushGold.withValues(alpha: 0.22)
                  : AppColors.blushGold.withValues(alpha: 0.10),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: AppColors.blushGold.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.suggestion.icon,
                size: 18,
                color: AppColors.blushGold.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 8),
              Text(
                widget.suggestion.text,
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.textMedium,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestion {
  final String text;
  final IconData icon;
  final String? route;

  const _Suggestion(this.text, this.icon, {this.route});
}

// ─── Delayed fade-in wrapper ────────────────────────────────────
// Implicit animations (AnimatedOpacity/AnimatedSlide) targeting visible:
// even if the widget rebuilds mid-entrance (e.g. a hover setState from a
// card below), the fade always converges to fully visible instead of
// stranding children at zero opacity.

class _DelayedFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _DelayedFadeIn({required this.child, this.delay = Duration.zero});

  @override
  State<_DelayedFadeIn> createState() => _DelayedFadeInState();
}

class _DelayedFadeInState extends State<_DelayedFadeIn> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      opacity: _visible ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, 0.05),
        child: widget.child,
      ),
    );
  }
}

// ─── Message bubble ──────────────────────────────────────────────

class _MessageBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final DateTime? timestamp;
  final bool isStreaming;
  final String? reasoning;
  final String? toolStatus;
  final List<String> imageUrls;

  const _MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.timestamp,
    this.isStreaming = false,
    this.reasoning,
    this.toolStatus,
    this.imageUrls = const [],
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

/// Renders attached images inside a message bubble. The URLs are base64
/// data URIs (sent to the vision API), so they are decoded and shown with
/// [Image.memory].
