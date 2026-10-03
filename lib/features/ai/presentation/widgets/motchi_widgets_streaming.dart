part of 'motchi_screen.dart';

class _StreamingPlaceholder extends StatelessWidget {
  const _StreamingPlaceholder();

  @override
  Widget build(BuildContext context) {
    // Live tool chips render separately in [_LiveToolStrip] below the
    // bubble — this placeholder only covers the pre-text thinking wait.
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: _RotatingThinkingText()),
        SizedBox(width: 8),
        _ThreeDots(),
      ],
    );
  }
}

/// Rotates through short "thinking" phrases so the pre-answer wait feels
/// alive instead of a frozen gap (the model can stay silent for seconds
/// while it reasons).
class _RotatingThinkingText extends StatefulWidget {
  const _RotatingThinkingText();

  @override
  State<_RotatingThinkingText> createState() => _RotatingThinkingTextState();
}

class _RotatingThinkingTextState extends State<_RotatingThinkingText> {
  static const _phrases = [
    'Motchi is thinking',
    'Motchi is weaving her thoughts',
    'Motchi is remembering your little things',
    'Motchi is finding the right words',
    'Motchi is dreaming up something nice',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _phrases.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Text(
        _phrases[_index],
        key: ValueKey(_index),
        style: AppTypography.bodyMedium().copyWith(
          color: AppColors.textMuted,
          height: 1.45,
        ),
      ),
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
    )..repeat();
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
    )..repeat(reverse: true);
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
        opacity: 0.25 + 0.75 * _c.value,
        child: Container(
          width: 2.5,
          height: 15,
          decoration: BoxDecoration(
            color: AppColors.blushGold,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
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
              const _MotchiAvatar(size: 24),
              const SizedBox(width: 8),
              Text('Motchi', style: AppTypography.bodySmall()),
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
                      color: AppColors.moonlight.withValues(alpha: 0.055),
                      borderRadius: AppRadius.radiusXl,
                      border: Border.all(
                        color: _focused
                            ? AppColors.roseQuartz.withValues(alpha: 0.45)
                            : AppColors.border,
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
                              color: AppColors.petalWhite,
                              height: 1.5,
                            ),
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: 'Message Motchi…',
                              hintStyle: AppTypography.bodyLarge().copyWith(
                                color: AppColors.textDisabled,
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
                                    CheckedPopupMenuItem(
                                      value: 'canvas',
                                      checked: widget.canvasEnabled,
                                      child: Text(
                                        'Canvas',
                                        style: AppTypography.bodyMedium(),
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
                                    shape: const CircleBorder(),
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
