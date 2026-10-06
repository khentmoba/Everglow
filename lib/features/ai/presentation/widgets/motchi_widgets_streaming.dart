part of 'motchi_screen.dart';

class _StreamingPlaceholder extends StatelessWidget {
  const _StreamingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Thinking…',
            style: AppTypography.bodyMedium().copyWith(
              fontFamily: AppTypography.reading,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const _ThreeDots(),
      ],
    );
  }
}

/// Three animated dots, reused by the thinking states.
class _ThreeDots extends StatefulWidget {
  const _ThreeDots();

  @override
  State<_ThreeDots> createState() => _ThreeDotsState();
}

class _ThreeDotsState extends State<_ThreeDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (!AppMotion.reduced) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value - i * 0.18).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
            final scale = 0.75 + 0.45 * opacity;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.roseQuartz,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Motchi's avatar with a soft breathing rose halo and lively aura.
///
/// The one "I'm working on it" tell for the whole answering window —
/// from the first thinking dot through every tool round to the last
/// streamed word. Stays a still halo when the user asked for reduced
/// motion (AppMotion.reduced).
class _AnsweringAvatar extends StatefulWidget {
  const _AnsweringAvatar({this.size = 20});

  final double size;

  @override
  State<_AnsweringAvatar> createState() => _AnsweringAvatarState();
}

class _AnsweringAvatarState extends State<_AnsweringAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (!AppMotion.reduced) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Outer diffuse glow bloom
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = Curves.easeInOut.transform(_c.value);
            return Container(
              width: widget.size * 2.6,
              height: widget.size * 2.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.auroraRose.withValues(
                      alpha: AppMotion.reduced ? 0.08 : (0.05 + 0.15 * t),
                    ),
                    AppColors.blushGold.withValues(
                      alpha: AppMotion.reduced ? 0.04 : (0.02 + 0.08 * t),
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
        // Primary halo: preserves key and radial gradient color alpha animation for test verification
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = Curves.easeInOut.transform(_c.value);
            return Container(
              key: const ValueKey('motchi-answering-halo'),
              width: widget.size * 2.1,
              height: widget.size * 2.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.auroraRose.withValues(alpha: 0.10 + 0.30 * t),
                    AppColors.auroraRose.withValues(alpha: 0),
                  ],
                ),
              ),
            );
          },
        ),
        // Breathing avatar with soft shadow pulse
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = Curves.easeInOut.transform(_c.value);
            final scale = AppMotion.reduced ? 1.0 : (1.0 + 0.06 * t);
            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.auroraRose.withValues(
                        alpha: AppMotion.reduced ? 0.25 : (0.20 + 0.35 * t),
                      ),
                      blurRadius: AppMotion.reduced ? 8 : (8 + 5 * t),
                      spreadRadius: AppMotion.reduced ? 1 : (1 + 2 * t),
                    ),
                  ],
                ),
                child: _MotchiAvatar(size: widget.size),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Animated badge beside Motchi's name showing she is replying / thinking.
class _ReplyingBadge extends StatefulWidget {
  final bool isThinking;
  const _ReplyingBadge({this.isThinking = false});

  @override
  State<_ReplyingBadge> createState() => _ReplyingBadgeState();
}

class _ReplyingBadgeState extends State<_ReplyingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (!AppMotion.reduced) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        final pulse = math.sin(t * math.pi).clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.auroraRose.withValues(
              alpha: AppMotion.reduced ? 0.12 : (0.08 + 0.08 * pulse),
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.auroraRose.withValues(
                alpha: AppMotion.reduced ? 0.25 : (0.20 + 0.18 * pulse),
              ),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: AppMotion.reduced ? 0.9 : (0.4 + 0.6 * pulse),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.roseQuartz,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                widget.isThinking ? 'thinking' : 'replying',
                style: AppTypography.labelSmall().copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.roseQuartz,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 4),
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Builder(
                  builder: (_) {
                    final phase = (t - i * 0.2) % 1.0;
                    final wave = math.sin(phase * math.pi).clamp(0.0, 1.0);
                    final y = AppMotion.reduced ? 0.0 : -1.8 * wave;
                    final alpha = AppMotion.reduced ? 0.7 : (0.35 + 0.65 * wave);
                    return Transform.translate(
                      offset: Offset(0, y),
                      child: Opacity(
                        opacity: alpha,
                        child: Container(
                          width: 2.5,
                          height: 2.5,
                          decoration: const BoxDecoration(
                            color: AppColors.roseQuartz,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Blinking caret shown at the end of a live-streaming reply.
class _StreamingCaret extends StatefulWidget {
  const _StreamingCaret();

  @override
  State<_StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<_StreamingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    if (!AppMotion.reduced) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Opacity(
        opacity: AppMotion.reduced ? 0.8 : (0.25 + 0.75 * _c.value),
        child: Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.blushGold,
            borderRadius: BorderRadius.circular(1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.blushGold.withValues(
                  alpha: AppMotion.reduced ? 0.25 : (0.20 + 0.35 * _c.value),
                ),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trailing indicator showing Motchi is actively typing/replying at the stream tail.
class _StreamingTailIndicator extends StatelessWidget {
  const _StreamingTailIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StreamingCaret(),
        SizedBox(width: 7),
        _StreamingDotsWave(),
      ],
    );
  }
}

/// Three micro-dots doing a gentle wave while Motchi generates text.
class _StreamingDotsWave extends StatefulWidget {
  const _StreamingDotsWave();

  @override
  State<_StreamingDotsWave> createState() => _StreamingDotsWaveState();
}

class _StreamingDotsWaveState extends State<_StreamingDotsWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (!AppMotion.reduced) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Builder(
                builder: (_) {
                  final phase = (t - i * 0.22) % 1.0;
                  final wave = math.sin(phase * math.pi).clamp(0.0, 1.0);
                  final dotScale = AppMotion.reduced ? 1.0 : (0.75 + 0.40 * wave);
                  final dotOpacity = AppMotion.reduced ? 0.7 : (0.35 + 0.65 * wave);
                  return Opacity(
                    opacity: dotOpacity,
                    child: Transform.scale(
                      scale: dotScale,
                      child: Container(
                        width: 4.5,
                        height: 4.5,
                        decoration: const BoxDecoration(
                          color: AppColors.roseQuartz,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─── Thinking indicator ─────────────────────────────────────────

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _AnsweringAvatar(size: 20),
              const SizedBox(width: 8),
              Text(
                'Motchi',
                style: AppTypography.bodySmall().copyWith(
                  fontFamily: AppTypography.reading,
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(width: 8),
              const _ReplyingBadge(isThinking: true),
            ],
          ),
          const SizedBox(height: 12),
          const _StreamingPlaceholder(),
        ],
      ),
    );
  }
}

// ─── Error banner ───────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String? lastSentMessage;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.lastSentMessage, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Consumer<AIService>(
      builder: (_, ai, _) {
        final error = ai.lastError;
        if (error == null || lastSentMessage == null) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.deepRose.withValues(alpha: 0.15),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: AppColors.deepRose.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.deepRose,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error.contains('too large') || error.contains('413')
                      ? error
                      : 'Motchi got distracted. Try again?',
                  style: AppTypography.bodySmall().copyWith(
                    color: AppColors.textMedium,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.deepRose.withValues(alpha: 0.2),
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text(
                    'Retry',
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.petalWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Composer input ─────────────────────────────────────────────

class _ComposerInput extends StatefulWidget {
  final GlobalKey inputKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onPickImages;
  final List<String> attachedImages;
  final void Function(int) onRemoveImage;
  final bool centered;
  final DeepThinkMode deepThinkMode;
  final VoidCallback onToggleDeepThink;
  // Canvas toggle — ON shows the interactive quiz / flashcards buttons,
  // OFF keeps Motchi as plain chat. Defaults OFF.
  final bool canvasEnabled;
  final VoidCallback? onToggleCanvas;

  const _ComposerInput({
    required this.inputKey,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onStop,
    required this.onPickImages,
    this.attachedImages = const [],
    required this.onRemoveImage,
    this.centered = false,
    required this.deepThinkMode,
    required this.onToggleDeepThink,
    this.canvasEnabled = false,
    this.onToggleCanvas,
  });

  @override
  State<_ComposerInput> createState() => _ComposerInputState();
}

class _ComposerInputState extends State<_ComposerInput> {
  bool _hasText = false;
  bool _isListening = false;
  bool _focused = false;
  final MotchiWebBridge _bridge = MotchiWebBridge();

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  Future<void> _startVoice() async {
    if (!_bridge.isSpeechSupported || _isListening) return;
    setState(() => _isListening = true);
    try {
      final result = await _bridge.recognizeOnce(lang: 'en-US');
      if (result != null && result.trim().isNotEmpty && mounted) {
        final current = widget.controller.text;
        final next = current.isEmpty
            ? result.trim()
            : '$current ${result.trim()}';
        widget.controller.text = next;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: next.length),
        );
      }
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AIService, bool>(
      selector: (_, ai) => ai.isLoading,
      builder: (context, isLoading, _) {
        final canSend = _hasText || widget.attachedImages.isNotEmpty;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 752),
            child: Padding(
              key: widget.inputKey,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.attachedImages.isNotEmpty)
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.attachedImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.radiusMd,
                              child: Image.memory(
                                _decodeBase64(widget.attachedImages[i]),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                tooltip: 'Remove image',
                                onPressed: () => widget.onRemoveImage(i),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.inkDeep,
                                  foregroundColor: AppColors.petalWhite,
                                  minimumSize: const Size(44, 44),
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    decoration: BoxDecoration(
                      color: AppColors.silk.withValues(alpha: 0.55),
                      borderRadius: AppRadius.radiusLg,
                      border: Border.all(
                        color: _focused
                            ? AppColors.roseQuartz.withValues(alpha: 0.45)
                            : AppColors.moonlight.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Focus(
                      onFocusChange: (v) => setState(() => _focused = v),
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed &&
                            !isLoading &&
                            canSend) {
                          widget.onSend();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            style: AppTypography.bodyLarge().copyWith(
                              fontFamily: AppTypography.reading,
                              fontWeight: FontWeight.w400,
                              color: AppColors.petalWhite,
                              height: 1.5,
                            ),
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: 'Message Motchi…',
                              hintStyle: AppTypography.bodyLarge().copyWith(
                                fontFamily: AppTypography.reading,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                4,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 2, 8, 8),
                            child: Row(
                              children: [
                                PopupMenuButton<String>(
                                  tooltip: 'Add to message',
                                  icon: _isListening
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.roseQuartz,
                                            semanticsLabel: 'Listening',
                                          ),
                                        )
                                      : Icon(
                                          Icons.add_rounded,
                                          color: AppColors.textMuted,
                                          size: 22,
                                        ),
                                  color: AppColors.silk,
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.radiusLg,
                                  ),
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'images':
                                        widget.onPickImages();
                                      case 'voice':
                                        _startVoice();
                                      case 'canvas':
                                        widget.onToggleCanvas?.call();
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'images',
                                      child: Text(
                                        'Attach images',
                                        style: AppTypography.bodyMedium(),
                                      ),
                                    ),
                                    if (_bridge.isSpeechSupported)
                                      PopupMenuItem(
                                        value: 'voice',
                                        enabled: !_isListening,
                                        child: Text(
                                          _isListening
                                              ? 'Listening…'
                                              : 'Voice input',
                                          style: AppTypography.bodyMedium(),
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 'canvas',
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.dashboard_customize_outlined,
                                            size: 18,
                                            color: widget.canvasEnabled
                                                ? AppColors.roseQuartz
                                                : AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Canvas',
                                            style: AppTypography.bodyMedium(),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            widget.canvasEnabled ? 'On' : 'Off',
                                            style: AppTypography.labelSmall()
                                                .copyWith(
                                                  color: widget.canvasEnabled
                                                      ? AppColors.roseQuartz
                                                      : AppColors.textMuted,
                                                ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            widget.canvasEnabled
                                                ? Icons.toggle_on_rounded
                                                : Icons.toggle_off_rounded,
                                            size: 28,
                                            color: widget.canvasEnabled
                                                ? AppColors.roseQuartz
                                                : AppColors.textMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                _DeepThinkPill(
                                  mode: widget.deepThinkMode,
                                  onTap: widget.onToggleDeepThink,
                                ),
                                if (widget.canvasEnabled)
                                  IconButton(
                                    tooltip: 'Canvas: on — tap to turn off',
                                    onPressed: widget.onToggleCanvas,
                                    color: AppColors.roseQuartz,
                                    icon: const Icon(
                                      Icons.dashboard_customize_outlined,
                                      size: 19,
                                    ),
                                  ),
                                const Spacer(),
                                IconButton(
                                  onPressed: isLoading
                                      ? widget.onStop
                                      : (canSend ? widget.onSend : null),
                                  tooltip: isLoading
                                      ? 'Stop generating'
                                      : 'Send message',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.roseQuartz,
                                    disabledBackgroundColor:
                                        AppColors.glassSoft,
                                    foregroundColor: AppColors.inkDeep,
                                    disabledForegroundColor:
                                        AppColors.textDisabled,
                                    minimumSize: const Size(44, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: AppRadius.radiusMd,
                                    ),
                                  ),
                                  icon: Icon(
                                    isLoading
                                        ? Icons.stop_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 21,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.centered)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Just for you two · Motchi can make mistakes',
                        style: AppTypography.bodySmall().copyWith(
                          color: AppColors.textDisabled,
                        ),
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

final Map<String, Uint8List> _base64Cache = <String, Uint8List>{};

Uint8List _decodeBase64(String dataUri) {
  final cached = _base64Cache[dataUri];
  if (cached != null) return cached;
  final base64Str = dataUri.split(',').last;
  final decoded = Uint8List.fromList(base64Decode(base64Str));
  if (_base64Cache.length >= 64) {
    _base64Cache.remove(_base64Cache.keys.first);
  }
  _base64Cache[dataUri] = decoded;
  return decoded;
}
