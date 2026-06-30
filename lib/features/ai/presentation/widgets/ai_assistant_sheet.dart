import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../data/services/ai_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_elevation.dart';

/// Shows the AI assistant as a bottom sheet with Mochi the cat.
void showAIAssistantSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => const _MochiPanel(),
  );
}

class _MochiPanel extends StatefulWidget {
  const _MochiPanel();
  @override
  State<_MochiPanel> createState() => _MochiPanelState();
}

class _MochiPanelState extends State<_MochiPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showScrollButton = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scroll.hasClients &&
        _scroll.position.maxScrollExtent - _scroll.position.pixels > 300;
    if (show != _showScrollButton) {
      setState(() => _showScrollButton = show);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        if (animated) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _focusNode.requestFocus();
    _scrollToBottom();

    try {
      final aiService = context.read<AIService>();
      final authService = context.read<AuthService>();

      await aiService.sendMessage(
        feature: 'assistant',
        message: text,
        stream: true,
        callerName: authService.currentUser,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mochi couldn\'t respond: $msg',
              style: AppTypography.bodySmall()),
          backgroundColor: AppColors.deepRose.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.radiusLg),
          margin: const EdgeInsets.all(AppSpacing.lg),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      margin: EdgeInsets.only(top: topPadding + 8),
      decoration: BoxDecoration(
        color: AppColors.twilight,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.x2)),
        border: Border(
          top: BorderSide(
              color: AppColors.blushGold.withValues(alpha: 0.15),
              width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Handle ────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.blushGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header with Mochi ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 10),
            child: Row(
              children: [
                // Mochi avatar with subtle glow
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.glowRose,
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.radiusLg,
                    child: Image.asset(
                      'assets/images/mochi_avatar.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mochi',
                        style: AppTypography.titleLarge().copyWith(
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        'your cat · knows everything',
                        style: AppTypography.bodySmall().copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Clear chat button
                Semantics(
                  button: true,
                  label: 'Clear chat',
                  child: Tooltip(
                    message: 'Clear chat',
                    child: GestureDetector(
                      onTap: () =>
                          context.read<AIService>().clearConversation('assistant'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          borderRadius: AppRadius.radiusLg,
                        ),
                        child: Icon(
                          Icons.delete_sweep_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
              height: 1,
              color: AppColors.blushGold.withValues(alpha: 0.06)),

          // ── Messages ──────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                Consumer<AIService>(
                  builder: (_, ai, __) {
                    final msgs = ai.assistantConversation?.messages ?? [];
                    final loading = ai.isLoading;

                    if (msgs.isEmpty && !loading) {
                      return _EmptyState(onTap: _sendQuick);
                    }

                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      itemCount: msgs.length + (loading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == msgs.length) {
                          if (ai.draftResponse.isNotEmpty) {
                            return _ChatBubble(
                              key: ValueKey('draft_${ai.draftResponse.length}'),
                              text: ai.draftResponse,
                              isUser: false,
                              isStreaming: true,
                            );
                          }
                          return const _TypingIndicator();
                        }
                        final msg = msgs[i];
                        return _ChatBubble(
                          key: ValueKey('msg_${msg.timestamp.millisecondsSinceEpoch}_$i'),
                          text: msg.content,
                          isUser: msg.role == 'user',
                          timestamp: msg.timestamp,
                        );
                      },
                    );
                  },
                ),
                // Scroll-to-bottom FAB
                if (_showScrollButton)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FadeIn(
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: () => _scrollToBottom(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border,
                            ),
                            boxShadow: AppElevation.e2,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Input ─────────────────────────────────────
          _InputBar(
            controller: _input,
            focusNode: _focusNode,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  void _sendQuick(String text) {
    _input.text = text;
    _send();
  }
}

// ─── Lightweight markdown renderer ────────────────────────────

class _MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const _MarkdownText({required this.text, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ?? AppTypography.bodyMedium().copyWith(
      color: AppColors.textHigh,
      height: 1.5,
    );

    return RichText(
      text: TextSpan(
        style: style,
        children: _parseInline(text, style),
      ),
    );
  }

  List<TextSpan> _parseInline(String input, TextStyle base) {
    final spans = <TextSpan>[];
    // Simple regex-like parsing for bold, italic, inline code
    final regex = RegExp(
      r'(\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_|`(.+?)`|```[\s\S]*?```)',
    );

    int lastEnd = 0;
    for (final match in regex.allMatches(input)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: input.substring(lastEnd, match.start)));
      }

      final full = match.group(0)!;
      if (full.startsWith('**')) {
        spans.add(TextSpan(
          text: match.group(2),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (full.startsWith('__')) {
        spans.add(TextSpan(
          text: match.group(3),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (full.startsWith('*')) {
        spans.add(TextSpan(
          text: match.group(4),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (full.startsWith('_')) {
        spans.add(TextSpan(
          text: match.group(5),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (full.startsWith('`')) {
        spans.add(TextSpan(
          text: match.group(6),
          style: base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: AppColors.velvet.withValues(alpha: 0.5),
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < input.length) {
      spans.add(TextSpan(text: input.substring(lastEnd)));
    }

    return spans.isNotEmpty ? spans : [TextSpan(text: input)];
  }
}

// ─── Empty state ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final void Function(String) onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mochi avatar with glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.glowRose,
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.radiusX2,
                  child: Image.asset(
                    'assets/images/mochi_avatar.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Mew! What\'s up?',
                style: AppTypography.titleLarge().copyWith(
                  fontSize: 24,
                  color: AppColors.textHigh,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'I\'m Mochi, your cat. I live in Everglow\nand I know everything about you two.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              _QuickPill(
                label: 'What should we watch tonight?',
                onTap: () =>
                    onTap('What should we watch tonight?'),
              ),
              const SizedBox(height: 8),
              _QuickPill(
                label: 'Suggest a date idea',
                onTap: () =>
                    onTap('Suggest a romantic date idea for us'),
              ),
              const SizedBox(height: 8),
              _QuickPill(
                label: 'What have we been up to?',
                onTap: () =>
                    onTap('Give me a quick summary of what we\'ve been up to'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall().copyWith(
            color: AppColors.textMedium,
          ),
        ),
      ),
    );
  }
}

// ─── Chat bubble ──────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime? timestamp;
  final bool isStreaming;

  const _ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.timestamp,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = isUser ? text : _stripMarkdown(text);
    final showTimestamp = timestamp != null;
    final timeStr = timestamp != null
        ? DateFormat('h:mm a').format(timestamp!)
        : '';
    final isToday = timestamp != null &&
        DateTime.now().day == timestamp!.day &&
        DateTime.now().month == timestamp!.month &&
        DateTime.now().year == timestamp!.year;
    final fullDateStr = timestamp != null
        ? DateFormat('MMM d, h:mm a').format(timestamp!)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mochi avatar for assistant messages
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ClipRRect(
                    borderRadius: AppRadius.radiusSm,
                    child: Image.asset(
                      'assets/images/mochi_avatar.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (!isUser) const SizedBox(width: 8),

              // The bubble itself
              Flexible(
                child: GestureDetector(
                  onLongPress: () {
                    HapticFeedback.selectionClick();
                    Clipboard.setData(ClipboardData(text: displayText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied to clipboard',
                          style: AppTypography.bodySmall(),
                        ),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppColors.velvet,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusLg),
                        margin: const EdgeInsets.all(AppSpacing.lg),
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? LinearGradient(
                              colors: [
                                AppColors.deepRose
                                    .withValues(alpha: 0.65),
                                AppColors.deepRose
                                    .withValues(alpha: 0.35),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isUser ? null : AppColors.surfaceGlass,
                      borderRadius: BorderRadius.only(
                        topLeft: isUser
                            ? Radius.circular(AppRadius.lg)
                            : const Radius.circular(4),
                        topRight: isUser
                            ? const Radius.circular(4)
                            : Radius.circular(AppRadius.lg),
                        bottomLeft: Radius.circular(AppRadius.lg),
                        bottomRight: Radius.circular(AppRadius.lg),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: AppColors.border, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: (isUser
                                  ? AppColors.deepRose
                                  : AppColors.roseQuartz)
                              .withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // Message text with basic markdown for Mochi
                        if (isUser)
                          Text(
                            text,
                            style: AppTypography.bodyMedium().copyWith(
                              color: AppColors.petalWhite,
                              height: 1.45,
                            ),
                          )
                        else
                          _MarkdownText(
                            text: text,
                            baseStyle: AppTypography.bodyMedium()
                                .copyWith(
                              color: AppColors.textHigh,
                              height: 1.45,
                            ),
                          ),
                        // Timestamp
                        if (showTimestamp || isStreaming)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isStreaming)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppColors.blushGold,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 2,
                                        height: 2,
                                        decoration:
                                            const BoxDecoration(
                                          color: AppColors.twilight,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isStreaming)
                                  const SizedBox(width: 4),
                                Text(
                                  isStreaming
                                      ? 'thinking...'
                                      : isToday
                                          ? timeStr
                                          : fullDateStr,
                                  style: AppTypography.bodySmall()
                                      .copyWith(
                                    fontSize: 9,
                                    color: isUser
                                        ? AppColors.petalWhite
                                            .withValues(alpha: 0.55)
                                        : AppColors.textMuted
                                            .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // User avatar placeholder (initials)
              if (isUser)
                const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}

String _stripMarkdown(String text) {
  return text
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('*', '')
      .replaceAll('_', '')
      .replaceAll('`', '')
      .replaceAll('~~', '')
      .replaceAll('### ', '')
      .replaceAll('## ', '')
      .replaceAll('# ', '');
}

// ─── Typing indicator ──────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.radiusSm,
              child: Image.asset(
                'assets/images/mochi_avatar.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                        color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final delay = i * 0.25;
                      final t = (_c.value - delay).clamp(0.0, 1.0);
                      final opacity =
                          (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
                      final scale = 0.6 + (opacity * 0.4);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.roseQuartz
                                    .withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Input bar ──────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AIService>(
      builder: (_, ai, __) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            10,
            AppSpacing.lg,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppColors.blushGold.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: AppTypography.bodyMedium(),
                    decoration: InputDecoration(
                      hintText: 'Talk to Mochi…',
                      hintStyle: AppTypography.bodyMedium().copyWith(
                        color: AppColors.textDisabled,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Send button
              Semantics(
                button: true,
                label: 'Send message',
                child: GestureDetector(
                  onTap: ai.isLoading ? null : onSend,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: ai.isLoading
                          ? null
                          : const LinearGradient(
                              colors: [
                                AppColors.blushGold,
                                AppColors.deepRose
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: ai.isLoading
                          ? AppColors.surfaceGlass
                          : null,
                      borderRadius: AppRadius.radiusLg,
                      boxShadow: ai.isLoading
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.glowRose,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Center(
                      child: ai.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.blushGold,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              color: AppColors.petalWhite,
                              size: 22),
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
