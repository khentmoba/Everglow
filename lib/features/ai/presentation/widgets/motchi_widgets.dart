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
      cacheWidth: PerfSettings.sizedDecodeWidth((size * 3).round()),
      cacheHeight: PerfSettings.sizedDecodeWidth((size * 3).round()),
      filterQuality: FilterQuality.high,
      fit: BoxFit.cover,
    ),
  );
}

class _MotchiHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSidebarToggle;
  final VoidCallback? onNewChat;
  final bool sidebarOpen;

  const _MotchiHeader({
    required this.onBack,
    required this.onSidebarToggle,
    required this.onNewChat,
    this.sidebarOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: AppColors.textMuted,
            tooltip: 'Back',
          ),
          IconButton(
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onSidebarToggle,
            icon: Icon(
              sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
              size: 20,
            ),
            color: AppColors.textMuted,
            tooltip: sidebarOpen ? 'Close history' : 'History',
          ),
          const SizedBox(width: 8),
          const _MotchiAvatar(size: 32),
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
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onNewChat,
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            color: AppColors.textMuted,
            tooltip: 'New chat',
          ),
          PopupMenuButton<String>(
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              visualDensity: VisualDensity.standard,
            ),
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
  final ValueChanged<DeepThinkMode> onSelected;

  const _DeepThinkPill({required this.mode, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      DeepThinkMode.auto => 'Auto',
      DeepThinkMode.on => 'Deep',
      DeepThinkMode.off => 'Fast',
    };
    return PopupMenuButton<DeepThinkMode>(
      tooltip: 'Reply mode: $label',
      initialValue: mode,
      onSelected: onSelected,
      color: AppColors.silk,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
      itemBuilder: (_) => [
        for (final (value, title, description) in const [
          (DeepThinkMode.auto, 'Auto', 'Let Motchi choose how much to think'),
          (DeepThinkMode.on, 'Deep', 'Take more time for tricky questions'),
          (DeepThinkMode.off, 'Fast', 'Keep replies quick and simple'),
        ])
          PopupMenuItem(
            value: value,
            child: Row(
              children: [
                Icon(
                  value == mode ? Icons.check_rounded : Icons.remove_rounded,
                  size: 18,
                  color: value == mode
                      ? AppColors.roseQuartz
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppTypography.bodyMedium()),
                      Text(description, style: AppTypography.bodySmall()),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall().copyWith(
                  fontFamily: AppTypography.reading,
                  color: mode == DeepThinkMode.on
                      ? AppColors.roseQuartz
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
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
              const _MotchiAvatar(size: 56),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              Text(
                'Choose a starting point, then make it yours.',
                style: AppTypography.bodySmall().copyWith(
                  fontFamily: AppTypography.reading,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton(
                    onPressed: () => onTap(prompt),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMedium,
                      backgroundColor: AppColors.glassSoft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
  final VoidCallback? onUseAsDraft;
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
    this.onUseAsDraft,
    this.showArtifacts = true,
    this.keepFullText = false,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

/// Renders attached images inside a message bubble. The URLs are base64
/// data URIs (sent to the vision API), so they are decoded and shown with
/// [Image.memory].
