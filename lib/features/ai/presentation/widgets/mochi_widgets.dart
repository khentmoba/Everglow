part of 'mochi_screen.dart';

class _MochiHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSidebarToggle;
  final VoidCallback onNewChat;
  final bool deepThink;
  final VoidCallback onToggleDeepThink;

  const _MochiHeader({
    required this.onBack,
    required this.onSidebarToggle,
    required this.onNewChat,
    required this.deepThink,
    required this.onToggleDeepThink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
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
          Text(
            'Mochi',
            style: AppTypography.titleLarge().copyWith(fontSize: 18),
          ),
          const Spacer(),
          // Memory Book / Trivia / Today quick links
          if (MediaQuery.sizeOf(context).width >= 520) ...[
            IconButton(
              onPressed: () => context.push('/mochi-memory'),
              icon: Icon(
                Icons.menu_book_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              tooltip: 'Memory Book',
            ),
            IconButton(
              onPressed: () => context.push('/mochi-trivia'),
              icon: Icon(
                Icons.quiz_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              tooltip: 'Memory Trivia',
            ),
            IconButton(
              onPressed: () => context.push('/mochi-today'),
              icon: Icon(
                Icons.wb_twilight_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              tooltip: 'Mochi Today',
            ),
          ],
          // New chat button
          IconButton(
            onPressed: onNewChat,
            icon: Icon(Icons.add_rounded, color: AppColors.textMuted, size: 20),
            tooltip: 'New chat',
          ),
          // Deep thinking toggle: slower but more thoughtful replies.
          IconButton(
            onPressed: onToggleDeepThink,
            icon: Icon(
              deepThink
                  ? Icons.psychology_rounded
                  : Icons.psychology_outlined,
              color: deepThink
                  ? AppColors.blushGold
                  : AppColors.textMuted,
              size: 20,
            ),
            tooltip: deepThink ? 'Deep thinking: on' : 'Deep thinking: off',
          ),
          // Sidebar toggle
          IconButton(
            onPressed: onSidebarToggle,
            icon: Icon(
              Icons.menu_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            tooltip: 'History',
          ),
        ],
      ),
    );
  }
}

// ─── Empty state with greeting & suggested actions ───────────────

class _GreetingEmptyState extends StatelessWidget {
  final void Function(String) onTap;
  const _GreetingEmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated title
            _DelayedFadeIn(
              delay: const Duration(milliseconds: 0),
              child: Text(
                'Ask Mochi anything',
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge().copyWith(
                  fontSize: 26,
                  color: AppColors.textHigh,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Subtitle
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
            // Suggested actions 2x2 grid
            _SuggestedGrid(onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _SuggestedGrid extends StatelessWidget {
  final void Function(String) onTap;
  const _SuggestedGrid({required this.onTap});

  static const _suggestions = [
    _Suggestion(
      'Add a movie to our watchlist',
      Icons.movie_filter_outlined,
    ),
    _Suggestion(
      'Save a note to the Starlight Jar',
      Icons.auto_awesome_outlined,
    ),
    _Suggestion(
      'Plan a date for us',
      Icons.calendar_month_outlined,
    ),
    _Suggestion(
      'How are we doing today?',
      Icons.favorite_outline_rounded,
    ),
    _Suggestion(
      'Mochi Today',
      Icons.wb_twilight_rounded,
      route: '/mochi-today',
    ),
    _Suggestion(
      'Memory Trivia',
      Icons.quiz_rounded,
      route: '/mochi-trivia',
    ),
    _Suggestion(
      'Memory Book',
      Icons.menu_book_rounded,
      route: '/mochi-memory',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.9,
      ),
      itemCount: _suggestions.length,
      itemBuilder: (_, i) {
        return _DelayedFadeIn(
          delay: Duration(milliseconds: 200 + i * 80),
          child: GestureDetector(
            onTap: () {
              final route = _suggestions[i].route;
              if (route != null) {
                context.push(route);
              } else {
                onTap(_suggestions[i].text);
              }
            },
            child: AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: AppRadius.radiusLg,
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _suggestions[i].icon,
                    size: 18,
                    color: AppColors.blushGold.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _suggestions[i].text,
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
      },
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
