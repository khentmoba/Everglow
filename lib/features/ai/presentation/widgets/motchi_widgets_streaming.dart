part of 'motchi_screen.dart';

class _StreamingPlaceholder extends StatelessWidget {
  final String toolStatus;

  const _StreamingPlaceholder({required this.toolStatus});

  @override
  Widget build(BuildContext context) {
    if (_isToolAction(toolStatus)) {
      return _ToolStatusChip(status: toolStatus);
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [_RotatingThinkingText(), SizedBox(width: 8), _ThreeDots()],
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
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.blushGold, AppColors.auroraRose],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blushGold.withValues(alpha: 0.45),
                          blurRadius: 6,
                        ),
                      ],
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

/// Thin indeterminate bar that keeps the streaming state visibly "in
/// motion" while Motchi works on a reply.
class _StreamingProgressBar extends StatelessWidget {
  const _StreamingProgressBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 3,
        child: LinearProgressIndicator(
          backgroundColor: AppColors.inkDeep.withValues(alpha: 0.6),
          valueColor: const AlwaysStoppedAnimation(AppColors.blushGold),
        ),
      ),
    );
  }
}

// ─── Thinking indicator ─────────────────────────────────────────

class _ThinkingIndicator extends StatelessWidget {
  final String toolStatus;
  const _ThinkingIndicator({this.toolStatus = ''});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.45),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blushGold.withValues(alpha: 0.25),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/motchi_avatar.png',
                width: 32,
                height: 32,
                cacheWidth: kIsWeb ? null : 96,
                cacheHeight: kIsWeb ? null : 96,
                filterQuality: FilterQuality.high,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.velvet.withValues(alpha: 0.68),
                  AppColors.inkDeep.withValues(alpha: 0.88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.16),
                width: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isToolAction(toolStatus))
                  Text(
                    _formatToolStatus(toolStatus),
                    style: AppTypography.bodyMedium().copyWith(
                      color: AppColors.textMuted,
                      height: 1.0,
                    ),
                  )
                else
                  const _RotatingThinkingText(),
                const SizedBox(width: 8),
                const _ThreeDots(),
              ],
            ),
          ),
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
    widget.controller.addListener(_onTextChanged);
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
        final ai = context.read<AIService>();
        final canSend = _hasText || widget.attachedImages.isNotEmpty;
        final inner = Container(
          key: widget.inputKey,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            10,
            AppSpacing.lg,
            14 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppColors.blushGold.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.attachedImages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.attachedImages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.radiusSm,
                              child: Image.memory(
                                _decodeBase64(widget.attachedImages[i]),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => widget.onRemoveImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: AppColors.inkDeep.withValues(alpha: 0.72),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: AppColors.petalWhite,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.inkDeep.withValues(alpha: 0.92),
                      AppColors.velvet.withValues(alpha: 0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _focused
                        ? AppColors.blushGold.withValues(alpha: 0.42)
                        : AppColors.moonlight.withValues(alpha: 0.16),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    if (_focused)
                      BoxShadow(
                        color: AppColors.blushGold.withValues(alpha: 0.16),
                        blurRadius: 22,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Focus(
                  onFocusChange: (v) => setState(() => _focused = v),
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      if (!HardwareKeyboard.instance.isShiftPressed) {
                        widget.onSend();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          decoration: widget.attachedImages.isNotEmpty
                              ? BoxDecoration(
                                  color: AppColors.blushGold.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.blushGold.withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                )
                              : null,
                          child: IconButton(
                            onPressed: widget.onPickImages,
                            icon: Icon(
                              Icons.add_photo_alternate_rounded,
                              color: widget.attachedImages.isNotEmpty
                                  ? AppColors.blushGold
                                  : AppColors.textMuted,
                              size: 21,
                            ),
                            tooltip: 'Attach images',
                          ),
                        ),
                      ),
                      if (_bridge.isSpeechSupported)
                        IconButton(
                          onPressed: _isListening ? null : _startVoice,
                          icon: _isListening
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.blushGold,
                                  ),
                                )
                              : Icon(
                                  Icons.mic_none_rounded,
                                  color: AppColors.textMuted,
                                  size: 22,
                                ),
                          tooltip: _isListening
                              ? 'Listening...'
                              : 'Voice input',
                        ),
                      // Canvas toggle — glowing gold pill when ON.
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Tooltip(
                          message: widget.canvasEnabled
                              ? 'Canvas: on — quizzes open as interactive cards'
                              : 'Canvas: off — Motchi chats normally',
                          child: InkWell(
                            onTap: widget.onToggleCanvas,
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: widget.canvasEnabled
                                    ? AppColors.blushGold.withValues(alpha: 0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.canvasEnabled
                                      ? AppColors.blushGold.withValues(alpha: 0.40)
                                      : Colors.transparent,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.canvasEnabled
                                        ? Icons.dashboard_customize_rounded
                                        : Icons.dashboard_customize_outlined,
                                    color: widget.canvasEnabled
                                        ? AppColors.blushGold
                                        : AppColors.textMuted,
                                    size: 20,
                                  ),
                                  if (widget.canvasEnabled) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      'Canvas',
                                      style: AppTypography.labelSmall().copyWith(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.blushGold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          style: AppTypography.bodyMedium().copyWith(
                            color: AppColors.petalWhite,
                            height: 1.5,
                            fontSize: 14.5,
                          ),
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Share with Motchi… 🐾',
                            hintStyle: AppTypography.bodyMedium().copyWith(
                              color: AppColors.textDisabled,
                              fontSize: 13.5,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: GestureDetector(
                          onTap: ai.isLoading
                              ? widget.onStop
                              : (!canSend ? null : widget.onSend),
                          child: Tooltip(
                            message: ai.isLoading
                                ? 'Stop generating'
                                : 'Send message',
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: (!ai.isLoading && canSend)
                                    ? const LinearGradient(
                                        colors: [
                                          AppColors.deepRose,
                                          AppColors.auroraRose,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: ai.isLoading
                                    ? AppColors.deepRose.withValues(alpha: 0.45)
                                    : (!canSend
                                          ? AppColors.velvet.withValues(
                                              alpha: 0.55,
                                            )
                                          : null),
                                borderRadius: BorderRadius.circular(14),
                                border: (!ai.isLoading && canSend)
                                    ? Border.all(
                                        color: AppColors.petalWhite.withValues(
                                          alpha: 0.22,
                                        ),
                                        width: 1,
                                      )
                                    : null,
                                boxShadow: (!ai.isLoading && canSend)
                                    ? [
                                        BoxShadow(
                                          color: AppColors.deepRose.withValues(
                                            alpha: 0.45,
                                          ),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: ai.isLoading
                                    ? const Icon(
                                        Icons.stop_rounded,
                                        color: AppColors.petalWhite,
                                        size: 21,
                                      )
                                    : Icon(
                                        Icons.arrow_upward_rounded,
                                        color: canSend
                                            ? AppColors.petalWhite
                                            : AppColors.textDisabled,
                                        size: 21,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.centered)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '🐾 Motchi remembers privately for you two · history in the left panel',
                    style: AppTypography.bodySmall().copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 10.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
        if (!widget.centered) return inner;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: inner,
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
