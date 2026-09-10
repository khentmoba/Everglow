part of 'motchi_screen.dart';

class _MotchiHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSidebarToggle;
  final VoidCallback onNewChat;
  final DeepThinkMode deepThinkMode;
  final VoidCallback onToggleDeepThink;
  final bool isDesktop;
  final bool sidebarOpen;

  const _MotchiHeader({
    required this.onBack,
    required this.onSidebarToggle,
    required this.onNewChat,
    required this.deepThinkMode,
    required this.onToggleDeepThink,
    this.isDesktop = false,
    this.sidebarOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    final showNav = isDesktop || MediaQuery.sizeOf(context).width >= 520;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 10,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: isDesktop
            ? AppColors.inkDeep.withValues(alpha: 0.75)
            : AppColors.inkDeep.withValues(alpha: 0.40),
        border: Border(
          bottom: BorderSide(
            color: AppColors.blushGold.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onSidebarToggle,
            icon: Icon(
              sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
              color: AppColors.textMedium,
              size: 20,
            ),
            tooltip: sidebarOpen ? 'Close history' : 'History',
          ),
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textMedium,
              size: 18,
            ),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blushGold.withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset(
                    'assets/images/motchi_avatar.png',
                    width: 36,
                    height: 36,
                    cacheWidth: kIsWeb ? null : 108,
                    cacheHeight: kIsWeb ? null : 108,
                    filterQuality: FilterQuality.high,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.inkDeep, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Motchi',
                    style: AppTypography.titleLarge().copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.blushGold.withValues(alpha: 0.14),
                      borderRadius: AppRadius.radiusFull,
                    ),
                    child: Text(
                      '🐾 CAT',
                      style: AppTypography.labelSmall().copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.blushGold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Your cat who knows everything about you two',
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (showNav) ...[
            _HeaderActionButton(
              tooltip: 'Memory Book',
              icon: Icons.menu_book_rounded,
              onTap: () => context.push('/motchi-memory'),
            ),
            const SizedBox(width: 6),
            _HeaderActionButton(
              tooltip: 'Memory Trivia',
              icon: Icons.quiz_rounded,
              onTap: () => context.push('/motchi-trivia'),
            ),
            const SizedBox(width: 6),
            _HeaderActionButton(
              tooltip: 'Motchi Today',
              icon: Icons.wb_twilight_rounded,
              onTap: () => context.push('/motchi-today'),
            ),
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 20,
              color: AppColors.blushGold.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 6),
          ],
          _HeaderActionButton(
            tooltip: 'New chat',
            icon: Icons.add_rounded,
            onTap: onNewChat,
          ),
          const SizedBox(width: 6),
          _DeepThinkPill(
            mode: deepThinkMode,
            onTap: onToggleDeepThink,
          ),
        ],
      ),
    );
  }
}
class _HeaderActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(7.5),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            color: AppColors.textMedium,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _DeepThinkPill extends StatelessWidget {
  final DeepThinkMode mode;
  final VoidCallback onTap;

  const _DeepThinkPill({
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (tooltip, label, icon, activeColor, bgColor, hasGlow) = switch (mode) {
      DeepThinkMode.auto => (
        'Thinking: Auto (fast replies, deep reasoning when needed)',
        'Auto',
        Icons.auto_awesome_rounded,
        AppColors.blushGold,
        AppColors.blushGold.withValues(alpha: 0.12),
        false,
      ),
      DeepThinkMode.on => (
        'Thinking: Always on (deep reasoning)',
        'Deep',
        Icons.psychology_rounded,
        AppColors.blushGold,
        AppColors.blushGold.withValues(alpha: 0.22),
        true,
      ),
      DeepThinkMode.off => (
        'Thinking: Off (fastest replies)',
        'Fast',
        Icons.bolt_rounded,
        AppColors.textMuted,
        AppColors.surfaceGlass,
        false,
      ),
    };

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: mode == DeepThinkMode.off
                  ? AppColors.blushGold.withValues(alpha: 0.12)
                  : AppColors.blushGold.withValues(alpha: 0.35),
              width: 0.8,
            ),
            boxShadow: hasGlow
                ? [
                    BoxShadow(
                      color: AppColors.blushGold.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: activeColor,
                size: 16,
              ),
              const SizedBox(width: 4.5),
              Text(
                label,
                style: AppTypography.labelSmall().copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
              ),
            ],
          ),
        ),
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
      padding: EdgeInsets.symmetric(horizontal: centered ? 40 : 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Motchi welcoming avatar
          _DelayedFadeIn(
            delay: const Duration(milliseconds: 0),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blushGold.withValues(alpha: 0.28),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: AppColors.auroraRose.withValues(alpha: 0.15),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/images/motchi_avatar.png',
                  width: 76,
                  height: 76,
                  cacheWidth: kIsWeb ? null : 228,
                  cacheHeight: kIsWeb ? null : 228,
                  filterQuality: FilterQuality.high,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DelayedFadeIn(
            delay: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.blushGold.withValues(alpha: 0.12),
                borderRadius: AppRadius.radiusFull,
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Purring & ready for you two',
                    style: AppTypography.bodySmall().copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blushGold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DelayedFadeIn(
            delay: const Duration(milliseconds: 180),
            child: Text(
              'Ask Motchi anything',
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge().copyWith(
                fontSize: centered ? 30 : 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppColors.petalWhite,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _DelayedFadeIn(
            delay: const Duration(milliseconds: 260),
            child: Text(
              'Your companion cat who remembers all your special dates, games, movies & thoughts.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium().copyWith(
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 32),
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
    _Suggestion(
      'Build us a tiny game',
      Icons.sports_esports_rounded,
      accent: AppColors.auroraRose,
      badge: 'GAME',
    ),
    _Suggestion(
      'Quiz us with 5 fun questions',
      Icons.quiz_rounded,
      accent: AppColors.blushGold,
      badge: 'QUIZ',
    ),
    _Suggestion(
      'Save a note to the Starlight Jar',
      Icons.auto_awesome_rounded,
      accent: AppColors.auroraLilac,
      badge: 'STARLIGHT',
    ),
    _Suggestion(
      'Add a movie to our watchlist',
      Icons.movie_filter_rounded,
      accent: AppColors.auroraGold,
      badge: 'CINEMA',
    ),
    _Suggestion(
      'Plan a date for us',
      Icons.favorite_rounded,
      accent: AppColors.roseQuartz,
      badge: 'DATE',
    ),
    _Suggestion(
      'How are we doing today?',
      Icons.wb_sunny_rounded,
      accent: AppColors.auroraTeal,
      badge: 'STATUS',
    ),
    _Suggestion(
      'Motchi Today',
      Icons.wb_twilight_rounded,
      route: '/motchi-today',
      accent: AppColors.auroraGold,
      badge: 'RECAP',
    ),
    _Suggestion(
      'Memory Trivia',
      Icons.psychology_rounded,
      route: '/motchi-trivia',
      accent: AppColors.auroraLilac,
      badge: 'TRIVIA',
    ),
    _Suggestion(
      'Memory Book',
      Icons.menu_book_rounded,
      route: '/motchi-memory',
      accent: AppColors.roseQuartz,
      badge: 'MEMORIES',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = centered && w >= 900 ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: centered ? 2.0 : 1.9,
      ),
      itemCount: _suggestions.length,
      itemBuilder: (_, i) {
        return _DelayedFadeIn(
          delay: Duration(milliseconds: 200 + i * 80),
          child: _SuggestionCard(suggestion: _suggestions[i], onTap: onTap),
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
        // NOTE: do NOT put `transform` on the AnimatedContainer here — on
        // Flutter Web (release) a non-null implicit transform layer leaves
        // the whole card unpainted until a hover forces a repaint, then it
        // vanishes again on mouse-leave. The lift runs through
        // AnimatedSlide instead, which paints reliably.
        child: AnimatedSlide(
          duration: AppMotion.fast,
          curve: AppMotion.easeOutStrong,
          offset: _hover ? const Offset(0, -0.02) : Offset.zero,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.easeOutStrong,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _hover
                  ? AppColors.inkDeep.withValues(alpha: 0.95)
                  : AppColors.inkDeep.withValues(alpha: 0.70),
              borderRadius: AppRadius.radiusXl,
              border: Border.all(
                color: _hover
                    ? widget.suggestion.accent.withValues(alpha: 0.45)
                    : widget.suggestion.accent.withValues(alpha: 0.16),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                if (_hover)
                  BoxShadow(
                    color: widget.suggestion.accent.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.suggestion.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.suggestion.accent.withValues(alpha: 0.30),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    widget.suggestion.icon,
                    size: 19,
                    color: widget.suggestion.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.suggestion.badge,
                        style: AppTypography.labelSmall().copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: widget.suggestion.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.suggestion.text,
                        style: AppTypography.bodySmall().copyWith(
                          color: AppColors.petalWhite,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          fontSize: 12.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  final Color accent;
  final String badge;

  const _Suggestion(
    this.text,
    this.icon, {
    this.route,
    this.accent = AppColors.blushGold,
    this.badge = 'MOTCHI',
  });
}

// ─── Delayed fade-in wrapper ────────────────────────────────────

class _DelayedFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _DelayedFadeIn({required this.child, this.delay = Duration.zero});

  @override
  State<_DelayedFadeIn> createState() => _DelayedFadeInState();
}

class _DelayedFadeInState extends State<_DelayedFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value.dy * 30),
          child: child,
        ),
      ),
      child: widget.child,
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
  final String? senderName;
  // Canvas toggle from the chat bar — when false the bubble stays plain
  // text (hidden blocks still stripped so raw JSON never shows).
  final bool showArtifacts;

  /// When true the bubble keeps the full visible question/option list
  /// (the user explicitly asked to see it inline — see
  /// [userAskedForVisibleQuiz]). Defaults to false: collapse into the
  /// "Try the quiz" button.
  final bool keepFullText;

  const _MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.timestamp,
    this.isStreaming = false,
    this.reasoning,
    this.toolStatus,
    this.imageUrls = const [],
    this.senderName,
    this.showArtifacts = true,
    this.keepFullText = false,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

/// Renders attached images inside a message bubble. The URLs are base64
/// data URIs (sent to the vision API), so they are decoded and shown with
/// [Image.memory].
