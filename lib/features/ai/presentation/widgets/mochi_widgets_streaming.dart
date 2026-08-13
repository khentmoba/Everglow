part of 'mochi_screen.dart';

class _StreamingPlaceholder extends StatelessWidget {
  final String toolStatus;

  const _StreamingPlaceholder({required this.toolStatus});

  @override
  Widget build(BuildContext context) {
    if (_isToolAction(toolStatus)) {
      return _ToolStatusChip(status: toolStatus);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RotatingThinkingText(),
        const SizedBox(width: 8),
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
    'Mochi is thinking',
    'Mochi is weaving her thoughts',
    'Mochi is remembering your little things',
    'Mochi is finding the right words',
    'Mochi is dreaming up something nice',
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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.roseQuartz,
                    shape: BoxShape.circle,
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
/// motion" while Mochi works on a reply.
class _StreamingProgressBar extends StatelessWidget {
  const _StreamingProgressBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        minHeight: 2,
        backgroundColor: AppColors.moonlight.withValues(alpha: 0.14),
        valueColor: const AlwaysStoppedAnimation(AppColors.blushGold),
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
          ClipRRect(
            borderRadius: AppRadius.radiusSm,
            child: Image.asset(
              'assets/images/mochi_avatar.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.border, width: 0.5),
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
                      : 'Mochi got distracted. Try again?',
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
  final VoidCallback onPickImages;
  final List<String> attachedImages;
  final void Function(int) onRemoveImage;

  const _ComposerInput({
    required this.inputKey,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onPickImages,
    this.attachedImages = const [],
    required this.onRemoveImage,
  });

  @override
  State<_ComposerInput> createState() => _ComposerInputState();
}

class _ComposerInputState extends State<_ComposerInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
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
        return Container(
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
              // Attached images preview
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
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
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
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: AppRadius.radiusX2,
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Focus(
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
                      IconButton(
                        onPressed: widget.onPickImages,
                        icon: Icon(
                          Icons.add_photo_alternate_rounded,
                          color: widget.attachedImages.isNotEmpty
                              ? AppColors.blushGold
                              : AppColors.textMuted,
                          size: 22,
                        ),
                        tooltip: 'Attach images',
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          style: AppTypography.bodyMedium(),
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Talk to Mochi...',
                            hintStyle: AppTypography.bodyMedium().copyWith(
                              color: AppColors.textDisabled,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: GestureDetector(
                          onTap:
                              (ai.isLoading ||
                                  (!_hasText && widget.attachedImages.isEmpty))
                              ? null
                              : widget.onSend,
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient:
                                  (!ai.isLoading &&
                                      (_hasText ||
                                          widget.attachedImages.isNotEmpty))
                                  ? const LinearGradient(
                                      colors: [
                                        AppColors.blushGold,
                                        AppColors.deepRose,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color:
                                  (!ai.isLoading &&
                                      (_hasText ||
                                          widget.attachedImages.isNotEmpty))
                                  ? null
                                  : AppColors.velvet.withValues(alpha: 0.4),
                              borderRadius: AppRadius.radiusLg,
                            ),
                            child: Center(
                              child: ai.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.blushGold,
                                      ),
                                    )
                                  : Icon(
                                      Icons.arrow_upward_rounded,
                                      color:
                                          (_hasText ||
                                              widget.attachedImages.isNotEmpty)
                                          ? AppColors.petalWhite
                                          : AppColors.textDisabled,
                                      size: 20,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
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


