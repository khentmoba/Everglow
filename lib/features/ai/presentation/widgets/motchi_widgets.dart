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
          const _MotchiAvatar(size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Motchi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium().copyWith(
                fontFamily: AppTypography.reading,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: onNewChat,
            icon: const Icon(Icons.add_comment_outlined, size: 20),
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
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: mode == DeepThinkMode.on
              ? AppColors.roseQuartz
              : AppColors.textMuted,
          textStyle: AppTypography.bodySmall().copyWith(
            fontFamily: AppTypography.reading,
          ),
          minimumSize: const Size(64, 44),
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(label),
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
    final pet = motchiPetName(callerName);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pet.isEmpty
                    ? 'What’s on your mind?'
                    : 'What’s on your mind, $pet?',
                style: AppTypography.headlineLarge().copyWith(
                  fontSize: centered ? 40 : 36,
                  fontWeight: FontWeight.w400,
                  color: AppColors.petalWhite,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A small plan, a good film, or just a chat.',
                style: AppTypography.bodyMedium().copyWith(
                  fontFamily: AppTypography.reading,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMedium,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
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
                TextButton(
                  onPressed: () => onTap(prompt),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMedium,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size.fromHeight(48),
                    visualDensity: VisualDensity.standard,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusSm,
                    ),
                    textStyle: AppTypography.bodyMedium().copyWith(
                      fontFamily: AppTypography.reading,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 14),
                      Expanded(child: Text(label)),
                      const Icon(Icons.arrow_outward_rounded, size: 15),
                    ],
                  ),
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
