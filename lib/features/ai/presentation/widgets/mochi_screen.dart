import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/ai_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/utils/text_utils.dart';
import 'mochi_sidebar.dart';

/// Full-screen Mochi AI assistant, inspired by Vercel's chatbot interface.
class MochiScreen extends StatefulWidget {
  const MochiScreen({super.key});

  @override
  State<MochiScreen> createState() => _MochiScreenState();
}

class _MochiScreenState extends State<MochiScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _inputKey = GlobalKey();
  bool _showScrollButton = false;
  bool _isSending = false;
  String? _lastSentMessage;
  bool _isSidebarOpen = false;
  final List<String> _attachedImages = []; // base64 data URIs for preview
  final List<String> _attachedImageUrls = []; // public URLs for API
  final ImagePicker _picker = ImagePicker();
  html.EventListener? _pasteListener;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (kIsWeb) _setupClipboardPaste();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ai = context.read<AIService>();
      await ai.loadAssistantConversation();
      if (mounted && (ai.assistantConversation?.messages.isNotEmpty ?? false)) {
        _scrollToBottom(animated: false);
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _focusNode.dispose();
    if (_pasteListener != null) {
      html.window.removeEventListener('paste', _pasteListener);
    }
    super.dispose();
  }

  void _setupClipboardPaste() {
    _pasteListener = (html.Event event) {
      final e = event as html.ClipboardEvent;
      final items = e.clipboardData?.items;
      if (items == null) return;
      final length = items.length ?? 0;
      for (int i = 0; i < length; i++) {
        final item = items[i];
        if (item.type?.startsWith('image/') == true) {
          final file = item.getAsFile();
          if (file != null) {
            final reader = html.FileReader();
            reader.onLoadEnd.listen((_) {
              final result = reader.result as String?;
              if (result != null && result.contains(',')) {
                final base64Data = result.split(',').last;
                final ext = item.type?.split('/').last ?? 'png';
                final dataUri = 'data:image/$ext;base64,$base64Data';
                if (mounted) {
                  setState(() {
                    _attachedImages.add(dataUri);
                    _attachedImageUrls.add(dataUri);
                  });
                }
              }
            });
            reader.readAsDataUrl(file);
          }
          break;
        }
      }
    };
    html.window.addEventListener('paste', _pasteListener);
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
    if (_isSending) return;
    final text = _input.text.trim();
    final hasImages = _attachedImageUrls.isNotEmpty;
    if (text.isEmpty && !hasImages) return;
    _isSending = true;
    _lastSentMessage = text;
    _input.clear();
    if (mounted) setState(() {});
    _focusNode.requestFocus();
    _scrollToBottom();

    try {
      final aiService = context.read<AIService>();
      final authService = context.read<AuthService>();
      final imagesToSend = List<String>.from(_attachedImageUrls);
      setState(() {
        _attachedImages.clear();
        _attachedImageUrls.clear();
      });
      await aiService.sendMessage(
        feature: 'assistant',
        message: text,
        callerName: authService.currentUser,
        stream: true,
        imageUrls: imagesToSend,
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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          margin: const EdgeInsets.all(AppSpacing.lg),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _sendQuick(String text) {
    _input.text = text;
    _send();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        for (final image in images) {
          final bytes = await image.readAsBytes();
          final base64Data = 'data:image/${image.name.split('.').last};base64,${base64Encode(bytes)}';
          if (!mounted) return;
          setState(() {
            _attachedImages.add(base64Data);
            // For Agnes API, we need a publicly accessible URL.
            // Since we can't upload to a public URL in Flutter web directly,
            // we'll use base64 data URIs which Agnes supports via image_url.
            _attachedImageUrls.add(base64Data);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to attach images: $e',
                style: AppTypography.bodySmall()),
            backgroundColor: AppColors.deepRose.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _attachedImages.removeAt(index);
      _attachedImageUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.twilight,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                _MochiHeader(
                  onBack: () => context.pop(),
                  onSidebarToggle: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
                  onNewChat: _newChat,
                ),
                Divider(height: 1, color: AppColors.blushGold.withValues(alpha: 0.06)),
                Expanded(
                  child: Stack(
                    children: [
                      Consumer<AIService>(
                        builder: (_, ai, __) {
                          final allMsgs =
                              ai.assistantConversation?.messages ?? [];
                          final loading = ai.isLoading;
                          final hasDraft = ai.draftResponse.isNotEmpty;
                          final draftReasoning = ai.draftReasoning;
                          final toolStatus = ai.toolStatus;

                          if (allMsgs.isEmpty && !loading) {
                            return _GreetingEmptyState(onTap: _sendQuick);
                          }

                          final streamBubble = 1;
                          final itemCount = allMsgs.length +
                              (loading && !hasDraft ? 1 : 0) +
                              (hasDraft ? streamBubble : 0);

                          return ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            itemCount: itemCount,
                            itemBuilder: (_, i) {
                              int idx = 0;

                              final hasStream =
                                  hasDraft || draftReasoning.isNotEmpty;
                              if (hasStream && i == allMsgs.length + idx) {
                                return _MessageBubble(
                                  text: ai.draftResponse,
                                  isUser: false,
                                  isStreaming: true,
                                  reasoning: draftReasoning.isNotEmpty
                                      ? draftReasoning
                                      : null,
                                  toolStatus: toolStatus,
                                );
                              }
                              if (!hasStream && i == allMsgs.length + idx) {
                                return _ThinkingIndicator(
                                  toolStatus: toolStatus,
                                );
                              }
                              final msg = allMsgs[i - idx];
                              return _MessageBubble(
                                key: ValueKey(
                                    'msg_${msg.timestamp.millisecondsSinceEpoch}_$i'),
                                text: msg.content,
                                isUser: msg.role == 'user',
                                timestamp: msg.timestamp,
                              );
                            },
                          );
                        },
                      ),
                      if (_showScrollButton)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _showScrollButton ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                onTap: () => _scrollToBottom(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceGlass,
                                    borderRadius: AppRadius.radiusFull,
                                    border:
                                        Border.all(color: AppColors.border),
                                  ),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.textMuted,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _ErrorBanner(lastSentMessage: _lastSentMessage, onRetry: _send),
                _ComposerInput(
                  inputKey: _inputKey,
                  controller: _input,
                  focusNode: _focusNode,
                  onSend: _send,
                  onPickImages: _pickImages,
                  attachedImages: _attachedImages,
                  onRemoveImage: _removeImage,
                ),
              ],
            ),
          ),

          // Sidebar overlay
          MochiSidebar(
            isOpen: _isSidebarOpen,
            onClose: () => setState(() => _isSidebarOpen = false),
            onNewChat: _newChat,
          ),
        ],
      ),
    );
  }

  void _newChat() {
    final ai = context.read<AIService>();
    ai.clearConversation('assistant');
    setState(() => _isSidebarOpen = false);
    _scrollToBottom(animated: false);
  }
}

// ─── Header ──────────────────────────────────────────────────────

class _MochiHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSidebarToggle;
  final VoidCallback onNewChat;

  const _MochiHeader({
    required this.onBack,
    required this.onSidebarToggle,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textMuted, size: 20),
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
          // New chat button
          IconButton(
            onPressed: onNewChat,
            icon: Icon(Icons.add_rounded, color: AppColors.textMuted, size: 20),
            tooltip: 'New chat',
          ),
          // Sidebar toggle
          IconButton(
            onPressed: onSidebarToggle,
            icon: Icon(Icons.menu_rounded, color: AppColors.textMuted, size: 20),
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
    'What should we watch tonight?',
    'Suggest a date idea',
    'What have we been up to?',
    'How are our moods today?',
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
        childAspectRatio: 2.2,
      ),
      itemCount: _suggestions.length,
      itemBuilder: (_, i) {
        return _DelayedFadeIn(
          delay: Duration(milliseconds: 200 + i * 80),
          child: GestureDetector(
            onTap: () => onTap(_suggestions[i]),
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
              child: Text(
                _suggestions[i],
                style: AppTypography.bodySmall().copyWith(
                  color: AppColors.textMedium,
                  height: 1.35,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Delayed fade-in wrapper ────────────────────────────────────

class _DelayedFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _DelayedFadeIn({
    required this.child,
    this.delay = Duration.zero,
  });

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
        vsync: this, duration: const Duration(milliseconds: 500));
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

  const _MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.timestamp,
    this.isStreaming = false,
    this.reasoning,
    this.toolStatus,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showReasoning = true;

  @override
  Widget build(BuildContext context) {
    final displayText =
        widget.isUser ? widget.text : stripMarkdown(widget.text);
    final hasReasoning =
        widget.reasoning != null && widget.reasoning!.isNotEmpty;

    final timeStr = widget.timestamp != null
        ? DateFormat('h:mm a').format(widget.timestamp!)
        : '';
    final isToday = widget.timestamp != null &&
        DateTime.now().day == widget.timestamp!.day &&
        DateTime.now().month == widget.timestamp!.month &&
        DateTime.now().year == widget.timestamp!.year;
    final fullDateStr = widget.timestamp != null
        ? DateFormat('MMM d, h:mm a').format(widget.timestamp!)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isUser) ...[
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
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.selectionClick();
                Clipboard.setData(ClipboardData(text: displayText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied',
                        style: AppTypography.bodySmall()),
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppColors.velvet,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusLg),
                    margin: const EdgeInsets.all(AppSpacing.lg),
                  ),
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: widget.isUser
                      ? LinearGradient(
                          colors: [
                            AppColors.deepRose.withValues(alpha: 0.55),
                            AppColors.deepRose.withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.isUser ? null : AppColors.surfaceGlass,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                        widget.isUser ? AppRadius.lg : 4),
                    topRight: Radius.circular(
                        widget.isUser ? 4 : AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                    bottomRight: Radius.circular(AppRadius.lg),
                  ),
                  border: widget.isUser
                      ? null
                      : Border.all(
                          color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: widget.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (hasReasoning)
                      GestureDetector(
                        onTap: () => setState(
                            () => _showReasoning = !_showReasoning),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                AppColors.velvet.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.blushGold
                                  .withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.psychology_rounded,
                                      size: 14,
                                      color: AppColors.blushGold
                                          .withValues(alpha: 0.7)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Thinking${widget.isStreaming ? '...' : ''}',
                                    style: AppTypography.bodySmall()
                                        .copyWith(
                                      fontSize: 10,
                                      color: AppColors.textMuted
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _showReasoning
                                        ? Icons
                                            .keyboard_arrow_up_rounded
                                        : Icons
                                            .keyboard_arrow_down_rounded,
                                    size: 14,
                                    color: AppColors.textDisabled,
                                  ),
                                ],
                              ),
                              if (_showReasoning) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.reasoning!,
                                  style: AppTypography.bodySmall()
                                      .copyWith(
                                    fontSize: 10,
                                    color: AppColors.textMuted
                                        .withValues(alpha: 0.6),
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (widget.isUser)
                      Text(
                        widget.text,
                        style: AppTypography.bodyMedium().copyWith(
                          color: AppColors.petalWhite,
                          height: 1.45,
                        ),
                      )
                    else
                      widget.text.isEmpty && widget.isStreaming && widget.toolStatus != null && widget.toolStatus!.isNotEmpty
                          ? Text(
                              _formatToolStatus(widget.toolStatus!),
                              style: AppTypography.bodyMedium().copyWith(
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                                height: 1.45,
                              ),
                            )
                          : _MarkdownText(
                              text: widget.text,
                              baseStyle: AppTypography.bodyMedium().copyWith(
                                color: AppColors.textHigh,
                                height: 1.45,
                              ),
                            ),
                    if (widget.timestamp != null || widget.isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isStreaming) ...[
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
                                    decoration: const BoxDecoration(
                                      color: AppColors.twilight,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              widget.isStreaming
                                  ? 'replying...'
                                  : isToday
                                      ? timeStr
                                      : fullDateStr,
                              style: AppTypography.bodySmall().copyWith(
                                fontSize: 10,
                                color: widget.isUser
                                    ? AppColors.petalWhite
                                        .withValues(alpha: 0.5)
                                    : AppColors.textMuted
                                        .withValues(alpha: 0.6),
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
          if (widget.isUser) ...[
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: AppRadius.radiusSm,
              child: Image.asset(
                'assets/images/mochi_avatar.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Markdown renderer ───────────────────────────────────────────

class _MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const _MarkdownText({required this.text, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ??
        AppTypography.bodyMedium().copyWith(
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

String _formatToolStatus(String status) {
  if (status == 'generating') return 'Mochi is thinking';
  if (status == 'executing') return 'Mochi is working on it';
  if (status == 'done') return 'Mochi is done';
  if (status.startsWith('round_')) return 'Mochi is thinking';
  // Tool names
  const toolNames = {
    'add_to_watchlist': 'Adding to watchlist',
    'save_to_starlight_jar': 'Saving to Starlight Jar',
    'set_mood': 'Logging mood',
    'search_movies': 'Searching movies',
    'get_weather': 'Checking weather',
    'create_reminder': 'Creating reminder',
    'log_activity': 'Logging activity',
    'search_books': 'Searching books',
    'get_date_ideas': 'Getting date ideas',
    'read_chat_messages': 'Reading chat messages',
    'get_xp_stats': 'Checking XP stats',
    'search_anime': 'Searching anime',
  };
  return toolNames[status] ?? 'Mochi is thinking';
}

// ─── Thinking indicator ─────────────────────────────────────────

class _ThinkingIndicator extends StatefulWidget {
  final String toolStatus;
  const _ThinkingIndicator({this.toolStatus = ''});
  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Text(
                  widget.toolStatus.isNotEmpty
                      ? _formatToolStatus(widget.toolStatus)
                      : 'Mochi is thinking',
                  style: AppTypography.bodyMedium().copyWith(
                    color: AppColors.textMuted,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(3, (i) {
                  final delay = i * 0.2;
                  final t = (_c.value - delay).clamp(0.0, 1.0);
                  final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2)
                      .clamp(0.3, 1.0);
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 1.5),
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
      builder: (_, ai, __) {
        final error = ai.lastError;
        if (error == null || lastSentMessage == null) {
          return const SizedBox.shrink();
        }
        return Container(
          margin:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.deepRose.withValues(alpha: 0.15),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: AppColors.deepRose.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.deepRose, size: 18),
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
                      horizontal: 12, vertical: 6),
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
    return Consumer<AIService>(
      builder: (_, ai, __) {
        return Container(
          key: widget.inputKey,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            10,
            AppSpacing.lg,
            14 + MediaQuery.of(context).viewInsets.bottom,
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
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                                  child: const Icon(Icons.close,
                                      size: 12, color: Colors.white),
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
                  border: Border.all(
                    color: AppColors.border,
                    width: 0.5,
                  ),
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
                        icon: Icon(Icons.add_photo_alternate_rounded,
                            color: widget.attachedImages.isNotEmpty
                                ? AppColors.blushGold
                                : AppColors.textMuted,
                            size: 22),
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
                          onTap: (ai.isLoading || (!_hasText && widget.attachedImages.isEmpty))
                              ? null
                              : widget.onSend,
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: (!ai.isLoading && (_hasText || widget.attachedImages.isNotEmpty))
                                  ? const LinearGradient(
                                      colors: [
                                        AppColors.blushGold,
                                        AppColors.deepRose,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: (!ai.isLoading && (_hasText || widget.attachedImages.isNotEmpty))
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
                                      color: (_hasText || widget.attachedImages.isNotEmpty)
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

Uint8List _decodeBase64(String dataUri) {
  final base64Str = dataUri.split(',').last;
  return Uint8List.fromList(base64Decode(base64Str));
}
