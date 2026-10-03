part of 'motchi_screen.dart';

class _MotchiAvatar extends StatelessWidget {
  final double size;
  const _MotchiAvatar({this.size = 28});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.35),
    child: Image.asset(
      'assets/images/motchi_avatar.webp',
      width: size,
      height: size,
      cacheWidth: kIsWeb ? null : (size * 3).round(),
      cacheHeight: kIsWeb ? null : (size * 3).round(),
      filterQuality: FilterQuality.high,
      fit: BoxFit.cover,
    ),
  );
}

class _MotchiHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSidebarToggle;
  final VoidCallback onNewChat;
  final bool sidebarOpen;

  const _MotchiHeader({
    required this.onBack,
    required this.onSidebarToggle,
    required this.onNewChat,
    this.sidebarOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: AppColors.textMuted,
            tooltip: 'Back',
          ),
          IconButton(
            onPressed: onSidebarToggle,
            icon: Icon(
              sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
              size: 20,
            ),
            color: AppColors.textMuted,
            tooltip: sidebarOpen ? 'Close history' : 'History',
          ),
          const SizedBox(width: 8),
          const _MotchiAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Motchi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium().copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onNewChat,
            icon: const Icon(Icons.edit_square, size: 20),
            color: AppColors.textMuted,
            tooltip: 'New chat',
          ),
          PopupMenuButton<String>(
            tooltip: 'More from Motchi',
            icon: Icon(Icons.more_horiz_rounded, color: AppColors.textMuted),
            color: AppColors.silk,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            onSelected: (route) => context.push(route),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: '/motchi-memory',
                child: Text('Memory Book', style: AppTypography.bodyMedium()),
              ),
              PopupMenuItem(
                value: '/motchi-trivia',
                child: Text('Memory Trivia', style: AppTypography.bodyMedium()),
              ),
              PopupMenuItem(
                value: '/motchi-today',
                child: Text('Motchi Today', style: AppTypography.bodyMedium()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeepThinkPill extends StatelessWidget {
  final DeepThinkMode mode;
  final VoidCallback onTap;

  const _DeepThinkPill({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, tooltip) = switch (mode) {
      DeepThinkMode.auto => ('Auto', 'Thinking: Auto — tap for deep reasoning'),
      DeepThinkMode.on => (
        'Deep',
        'Thinking: Always on — tap for fast replies',
      ),
      DeepThinkMode.off => (
        'Fast',
        'Thinking: Off — tap for automatic thinking',
      ),
    };
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.psychology_outlined, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: mode == DeepThinkMode.on
              ? AppColors.roseQuartz
              : AppColors.textMuted,
          textStyle: AppTypography.bodySmall(),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}

class _GreetingEmptyState extends StatelessWidget {
  final void Function(String) onTap;
  final bool centered;
  final String? callerName;

  const _GreetingEmptyState({
    required this.onTap,
    this.centered = false,
    this.callerName,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _MotchiAvatar(size: 56),
              const SizedBox(height: 24),
              Text(
                motchiGreetingTitle(now, callerName),
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge().copyWith(
                  fontSize: centered ? 36 : 32,
                  fontWeight: FontWeight.w600,
                  color: AppColors.petalWhite,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                motchiGreetingSubtitle(now),
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge().copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, prompt, icon) in const [
                    (
                      'Pick a movie',
                      'What should we watch tonight from our watchlist?',
                      Icons.movie_outlined,
                    ),
                    (
                      'Plan a date',
                      'Plan a cozy date night for us',
                      Icons.favorite_border_rounded,
                    ),
                    (
                      'Quiz us',
                      'Quiz us with 5 fun questions',
                      Icons.quiz_outlined,
                    ),
                    (
                      'Make a game',
                      'Build us a tiny game',
                      Icons.sports_esports_outlined,
                    ),
                  ])
                    ActionChip(
                      avatar: Icon(icon, size: 17, color: AppColors.textMuted),
                      label: Text(label),
                      labelStyle: AppTypography.bodySmall().copyWith(
                        color: AppColors.textMedium,
                      ),
                      onPressed: () => onTap(prompt),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusFull,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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
  final List<String> imageUrls;
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
    this.imageUrls = const [],
    this.showArtifacts = true,
    this.keepFullText = false,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

/// Renders attached images inside a message bubble. The URLs are base64
/// data URIs (sent to the vision API), so they are decoded and shown with
/// [Image.memory].
