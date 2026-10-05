import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/services/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_motion.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/utils/greeting_utils.dart';
import '../../../../../shared/utils/text_utils.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../../../../../shared/widgets/everglow/everglow_chat_bubble.dart';
import '../../../../../shared/widgets/everglow/everglow_markdown.dart';
import '../../../../ai/data/services/ai_service.dart';
import '../../../../ai/domain/models/ai_conversation.dart';
import '../../../../ai/domain/motchi_quality.dart';
import '../../../../ai/domain/motchi_reply_details.dart';
import '../../../../ai/presentation/widgets/motchi_reply_details_card.dart';
import '../../../../ai/presentation/widgets/motchi_web_bridge.dart';
import 'animex_controller.dart';
import 'package:everglow/core/perf/perf_settings.dart';

enum AnimeMotchiDeepThink { auto, on, off }

/// Dedicated temporary Motchi chat sidebar for the Anime section.
///
/// Looks exactly like the main Motchi chat — same bubbles, same composer,
/// same empty state — but stays a temporary unsaved session in a sliding
/// side panel.
class AnimeXMotchiSidebar extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final AnimeXController controller;
  final List<AIMessage> messages;
  final VoidCallback onClear;

  const AnimeXMotchiSidebar({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.controller,
    required this.messages,
    required this.onClear,
  });

  @override
  State<AnimeXMotchiSidebar> createState() => AnimeXMotchiSidebarState();
}

class AnimeXMotchiSidebarState extends State<AnimeXMotchiSidebar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final MotchiWebBridge _webBridge = MotchiWebBridge();

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  AnimeMotchiDeepThink _deepThink = AnimeMotchiDeepThink.auto;
  bool _isSending = false;
  String? _lastSentMessage;
  bool _showScrollButton = false;
  bool _hasText = false;
  bool _focused = false;
  bool _isListening = false;
  final List<String> _attachedImages = [];
  final List<String> _attachedImageUrls = [];
  String? _sessionId;
  AIService? _ai;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: AppMotion.orZero(const Duration(milliseconds: 260)),
      value: widget.isOpen ? 1.0 : 0.0,
    );
    _fade = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _anim,
        curve: AppMotion.drawer,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _scroll.addListener(_onScroll);
    _input.addListener(_onInputChanged);
    _webBridge.installPasteListener(_onPastedImage);
    _sessionId = 'temp_anime_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void didUpdateWidget(AnimeXMotchiSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _anim.forward();
        // Auto-focus input when opened
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isOpen) {
            _focusNode.requestFocus();
            _scrollToBottom(animated: false);
          }
        });
      } else {
        _anim.reverse();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ai ??= context.read<AIService>();
  }

  @override
  void dispose() {
    _anim.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _focusNode.dispose();
    _webBridge.uninstallPasteListener();
    super.dispose();
  }

  void _onInputChanged() {
    final has = _input.text.trim().isNotEmpty;
    if (has != _hasText && mounted) {
      setState(() => _hasText = has);
    }
  }

  void _onPastedImage(String dataUri) {
    if (!mounted) return;
    setState(() {
      _attachedImages.add(dataUri);
      _attachedImageUrls.add(dataUri);
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final cur = _scroll.offset;
    final show = (max - cur) > 300;
    if (show != _showScrollButton && mounted) {
      setState(() => _showScrollButton = show);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send({bool retry = false}) async {
    if (_isSending) return;
    final text = retry ? (_lastSentMessage ?? '').trim() : _input.text.trim();
    final hasImages = !retry && _attachedImageUrls.isNotEmpty;
    if (text.isEmpty && !hasImages) return;

    final ai = _ai ?? context.read<AIService>();
    final auth = context.read<AuthService>();
    final caller = auth.currentUser;

    if (!retry) {
      _input.clear();
      _lastSentMessage = text;
    }

    final imagesToSend = List<String>.from(_attachedImageUrls);
    setState(() {
      _isSending = true;
      _attachedImages.clear();
      _attachedImageUrls.clear();
      if (!retry) {
        widget.messages.add(
          AIMessage(
            role: 'user',
            content: text,
            imageUrls: imagesToSend,
          ),
        );
      }
    });

    _focusNode.requestFocus();
    _scrollToBottom();

    final bool enableThinking;
    switch (_deepThink) {
      case AnimeMotchiDeepThink.auto:
        enableThinking = const MotchiQuality().shouldAutoThink(text);
        break;
      case AnimeMotchiDeepThink.on:
        enableThinking = true;
        break;
      case AnimeMotchiDeepThink.off:
        enableThinking = false;
        break;
    }

    // Build context if watching an anime
    String? contextOverride;
    final watchItem = widget.controller.watchItem;
    if (watchItem != null) {
      final epNum = widget.controller.watchEpisode ?? 1;
      contextOverride =
          'User is currently in Everglow Anime watching "${watchItem.title}" '
          '(episode $epNum). Provide relevant anime insights, lore, or recommendations if asked.';
    }

    try {
      final assistantMsg = await ai.sendTemporaryMessage(
        message: text,
        history: widget.messages.isNotEmpty
            ? widget.messages.sublist(0, widget.messages.length - 1)
            : const [],
        callerName: caller,
        enableThinking: enableThinking,
        canvasEnabled: false,
        imageUrls: imagesToSend,
        sessionId: _sessionId,
        contextOverride: contextOverride,
      );

      if (mounted) {
        setState(() {
          if (assistantMsg.content.isNotEmpty) {
            widget.messages.add(assistantMsg);
          }
          _lastSentMessage = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[AnimeMotchi] error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _stop() {
    _ai?.cancelCurrentReply();
    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  void _cycleDeepThink() {
    HapticFeedback.lightImpact();
    setState(() {
      switch (_deepThink) {
        case AnimeMotchiDeepThink.auto:
          _deepThink = AnimeMotchiDeepThink.on;
          break;
        case AnimeMotchiDeepThink.on:
          _deepThink = AnimeMotchiDeepThink.off;
          break;
        case AnimeMotchiDeepThink.off:
          _deepThink = AnimeMotchiDeepThink.auto;
          break;
      }
    });
  }

  void _clearChat() {
    HapticFeedback.selectionClick();
    _stop();
    setState(() {
      widget.onClear();
      _sessionId = 'temp_anime_${DateTime.now().millisecondsSinceEpoch}';
      _lastSentMessage = null;
    });
    _scrollToBottom(animated: false);
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        for (final image in images) {
          final bytes = await image.readAsBytes();
          final base64Data = bytes.length > 300 * 1024
              ? await _webBridge.resizeImageToDataUri(bytes)
              : 'data:image/${image.name.split('.').last};base64,${base64Encode(bytes)}';
          if (!mounted) return;
          setState(() {
            _attachedImages.add(base64Data);
            _attachedImageUrls.add(base64Data);
          });
        }
      }
    } catch (e) {
      debugPrint('[AnimeMotchi] image pick error: $e');
    }
  }

  Future<void> _startVoice() async {
    if (!_webBridge.isSpeechSupported || _isListening) return;
    setState(() => _isListening = true);
    try {
      final result = await _webBridge.recognizeOnce(lang: 'en-US');
      if (result != null && result.trim().isNotEmpty && mounted) {
        final current = _input.text;
        final next =
            current.isEmpty ? result.trim() : '$current ${result.trim()}';
        _input.text = next;
        _input.selection = TextSelection.fromPosition(
          TextPosition(offset: next.length),
        );
      }
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _attachedImages.length) _attachedImages.removeAt(index);
      if (index < _attachedImageUrls.length) _attachedImageUrls.removeAt(index);
    });
  }

  void _sendPrompt(String prompt) {
    _input.text = prompt;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;
    final sidebarWidth = isDesktop
        ? 390.0
        : (isTablet ? 380.0 : math.min(size.width * 0.90, 400.0));

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        if (_anim.value == 0 && !widget.isOpen) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // Backdrop scrim on mobile/tablet or when tapped outside
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: _fade.value * (isDesktop ? 0.35 : 0.65),
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),

            // Sidebar panel sliding in from right
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: sidebarWidth,
              child: SlideTransition(
                position: _slide,
                child: Material(
                  color: Colors.transparent,
                  elevation: 20,
                  shadowColor: Colors.black87,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.inkDeep,
                      border: Border(
                        left: BorderSide(
                          color:
                              AppColors.moonlight.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 36,
                          offset: const Offset(-8, 0),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      left: false,
                      top: false,
                      bottom: false,
                      child: Column(
                        children: [
                          _buildHeader(),
                          Expanded(child: _buildChatBody()),
                          _buildErrorBanner(),
                          _buildComposer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Same header as the main Motchi chat: close, avatar, title, new chat.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textMuted,
            tooltip: 'Close',
          ),
          const SizedBox(width: 8),
          const _AnimeMotchiAvatar(size: 24),
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
            onPressed: _clearChat,
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            color: AppColors.textMuted,
            tooltip: 'New chat',
          ),
        ],
      ),
    );
  }

  Widget _buildChatBody() {
    final ai = _ai ?? context.watch<AIService>();
    final callerName = context.read<AuthService>().currentUser;
    final isStreaming = _isSending && ai.isLoading;

    if (widget.messages.isEmpty && !isStreaming) {
      return _buildEmptyState(callerName);
    }

    final itemCount = widget.messages.length + (isStreaming ? 1 : 0);

    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == widget.messages.length) {
              return _buildStreamingBubble(ai);
            }
            final msg = widget.messages[index];
            final isUserMsg = msg.role == 'user';
            Widget bubble = _AnimeMessageBubble(
              key: ValueKey(
                'ams_${msg.timestamp.millisecondsSinceEpoch}_$index',
              ),
              text: msg.content,
              isUser: isUserMsg,
              timestamp: msg.timestamp,
              imageUrls: msg.imageUrls,
            );
            if (!isUserMsg && msg.sources.isNotEmpty) {
              bubble = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  bubble,
                  const SizedBox(height: 6),
                  _AnimeWebSourcesCard(sources: msg.sources),
                ],
              );
            }
            if (!isUserMsg && !msg.details.isEmpty) {
              bubble = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  bubble,
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: MotchiReplyDetailsCard(details: msg.details),
                  ),
                ],
              );
            }
            return Align(
              alignment: isUserMsg
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: bubble,
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
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.panelGlass,
                      borderRadius: AppRadius.radiusFull,
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
    );
  }

  Widget _buildStreamingBubble(AIService ai) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ValueListenableBuilder<int>(
        valueListenable: ai.draftRevisionNotifier,
        builder: (context, _, _) {
          final hasStream = ai.draftResponse.isNotEmpty ||
              ai.draftReasoning.isNotEmpty ||
              ai.activeTools.isNotEmpty ||
              ai.toolResultsNotifier.value.isNotEmpty;
          if (hasStream) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnimeMessageBubble(
                  text: MotchiReplyDetails.visibleText(ai.draftResponse),
                  isUser: false,
                  isStreaming: true,
                  reasoning: ai.draftReasoning.isNotEmpty
                      ? ai.draftReasoning
                      : null,
                ),
                _AnimeLiveToolStrip(ai: ai),
                if (ai.toolResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: MotchiReplyDetailsCard(
                      details: MotchiReplyDetails.fromResults(ai.toolResults),
                    ),
                  ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AnimeThinkingIndicator(),
              _AnimeLiveToolStrip(ai: ai),
            ],
          );
        },
      ),
    );
  }

  /// Same empty state as main Motchi, with anime-flavored quick asks.
  Widget _buildEmptyState(String? callerName) {
    final pet = motchiPetName(callerName);
    final watchItem = widget.controller.watchItem;
    final List<(String, String, IconData)> asks;
    if (watchItem != null) {
      asks = [
        (
          'About this anime',
          'Tell me about the anime "${watchItem.title}" — synopsis, vibe, and why it is loved!',
          Icons.movie_filter_outlined,
        ),
        (
          'Like this one',
          'What anime are similar in vibe and genre to "${watchItem.title}"? Give 3 recommendations.',
          Icons.auto_awesome_outlined,
        ),
        (
          'Plan a watch night',
          'Plan a cozy anime night for us',
          Icons.favorite_border_rounded,
        ),
        (
          'What’s airing?',
          'What are the most popular and highly rated anime currently airing this season?',
          Icons.calendar_month_outlined,
        ),
      ];
    } else {
      asks = const [
        (
          'Recommend an anime',
          'Recommend anime like Frieren: Beyond Journey\'s End with rich worldbuilding and emotional depth.',
          Icons.auto_awesome_outlined,
        ),
        (
          'Couple romance',
          'What are the best cute, heartfelt romance anime for a couple to watch together?',
          Icons.favorite_border_rounded,
        ),
        (
          'What’s airing?',
          'What are the most popular and highly rated anime currently airing this season?',
          Icons.calendar_month_outlined,
        ),
        (
          'Explain lore',
          'Explain the worldline and time travel mechanics of Steins;Gate simply and clearly.',
          Icons.psychology_outlined,
        ),
      ];
    }

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
                  fontSize: 36,
                  fontWeight: FontWeight.w400,
                  color: AppColors.petalWhite,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Anime picks, lore, or just a chat.',
                style: AppTypography.bodyMedium().copyWith(
                  fontFamily: AppTypography.reading,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMedium,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              for (final (label, prompt, icon) in asks)
                TextButton(
                  onPressed: () => _sendPrompt(prompt),
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

  Widget _buildErrorBanner() {
    final ai = _ai ?? context.watch<AIService>();
    final error = ai.lastError;
    if (error == null || _lastSentMessage == null) {
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
            onTap: () => _send(retry: true),
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
  }

  /// Same composer as the main Motchi chat.
  Widget _buildComposer() {
    return Selector<AIService, bool>(
      selector: (_, ai) => ai.isLoading,
      builder: (context, isLoading, _) {
        final canSend = _hasText || _attachedImages.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_attachedImages.isNotEmpty)
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachedImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.radiusMd,
                          child: Image.memory(
                            _decodeBase64(_attachedImages[i]),
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
                            onPressed: () => _removeImage(i),
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
                      _send();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _input,
                        focusNode: _focusNode,
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
                                    _pickImages();
                                  case 'voice':
                                    _startVoice();
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
                                if (_webBridge.isSpeechSupported)
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
                              ],
                            ),
                            _AnimeDeepThinkPill(
                              mode: _deepThink,
                              onTap: _cycleDeepThink,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: isLoading
                                  ? _stop
                                  : (canSend ? _send : null),
                              tooltip: isLoading
                                  ? 'Stop generating'
                                  : 'Send message',
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.roseQuartz,
                                disabledBackgroundColor: AppColors.glassSoft,
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
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Temporary anime chat · Nothing is saved',
                  style: AppTypography.bodySmall().copyWith(
                    color: AppColors.textDisabled,
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

class _AnimeMotchiAvatar extends StatelessWidget {
  final double size;
  const _AnimeMotchiAvatar({this.size = 28});

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

class _AnimeDeepThinkPill extends StatelessWidget {
  final AnimeMotchiDeepThink mode;
  final VoidCallback onTap;

  const _AnimeDeepThinkPill({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, tooltip) = switch (mode) {
      AnimeMotchiDeepThink.auto =>
        ('Auto', 'Thinking: Auto — tap for deep reasoning'),
      AnimeMotchiDeepThink.on =>
        ('Deep', 'Thinking: Always on — tap for fast replies'),
      AnimeMotchiDeepThink.off =>
        ('Fast', 'Thinking: Off — tap for automatic thinking'),
    };
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: mode == AnimeMotchiDeepThink.on
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

/// Same message bubble as the main Motchi chat: soft user pill, plain
/// assistant text with a small Motchi header row.
class _AnimeMessageBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final DateTime? timestamp;
  final bool isStreaming;
  final String? reasoning;
  final List<String> imageUrls;

  const _AnimeMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.timestamp,
    this.isStreaming = false,
    this.reasoning,
    this.imageUrls = const [],
  });

  @override
  State<_AnimeMessageBubble> createState() => _AnimeMessageBubbleState();
}

class _AnimeMessageBubbleState extends State<_AnimeMessageBubble> {
  bool _showReasoning = true;

  @override
  void didUpdateWidget(covariant _AnimeMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isStreaming &&
        oldWidget.text.isNotEmpty &&
        widget.isStreaming &&
        widget.text.isEmpty) {
      _showReasoning = true;
      return;
    }
    if (oldWidget.text.isEmpty &&
        widget.text.isNotEmpty &&
        widget.isStreaming) {
      _showReasoning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleText = widget.isUser ? widget.text : widget.text.trimLeft();
    final displayText =
        widget.isUser ? widget.text : stripMarkdown(bubbleText);
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment:
            widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: () => copyText(context, displayText),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width *
                      (widget.isUser ? 0.85 : 1),
                ),
                padding: widget.isUser
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                    : EdgeInsets.zero,
                decoration: widget.isUser
                    ? BoxDecoration(
                        color: AppColors.glassSoft,
                        borderRadius: AppRadius.radiusLg,
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: widget.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!widget.isUser) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          widget.isStreaming
                              ? const _AnimeAnsweringAvatar(size: 20)
                              : const _AnimeMotchiAvatar(size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Motchi',
                            style: AppTypography.bodySmall().copyWith(
                              fontFamily: AppTypography.reading,
                              color: AppColors.textMedium,
                            ),
                          ),
                          if (widget.isStreaming) ...[
                            const SizedBox(width: 8),
                            _AnimeReplyingBadge(
                              isThinking: bubbleText.trim().isEmpty,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (hasReasoning)
                      GestureDetector(
                        onTap: () => setState(
                            () => _showReasoning = !_showReasoning),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glassSoft,
                            borderRadius: AppRadius.radiusMd,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.pets_rounded,
                                    size: 13,
                                    color: AppColors.blushGold,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Motchi\'s thoughts${widget.isStreaming ? '…' : ''}',
                                    style: AppTypography.bodySmall().copyWith(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.blushGold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _showReasoning
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 14,
                                    color: AppColors.blushGold.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ],
                              ),
                              if (_showReasoning) ...[
                                const SizedBox(height: 4),
                                EverglowMarkdown(
                                  text: widget.reasoning!,
                                  paragraphGap: 4,
                                  baseStyle:
                                      AppTypography.bodySmall().copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted,
                                    height: 1.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (widget.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _AnimeMessageImages(imageUrls: widget.imageUrls),
                      if (widget.text.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (widget.isUser)
                      Text(
                        widget.text,
                        style: AppTypography.bodyMedium().copyWith(
                          color: AppColors.petalWhite,
                          height: 1.55,
                          fontFamily: AppTypography.reading,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    else if (widget.isStreaming && bubbleText.isEmpty)
                      const _AnimeStreamingPlaceholder()
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AnimeMarkdownText(
                            text: bubbleText,
                            baseStyle:
                                AppTypography.bodyMedium().copyWith(
                              color: AppColors.textHigh,
                              fontFamily: AppTypography.reading,
                              height: 1.65,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (widget.isStreaming && bubbleText.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: _AnimeStreamingTailIndicator(),
                            ),
                        ],
                      ),
                    if (!widget.isUser && !widget.isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            if (displayText.trim().isNotEmpty) ...[
                              IconButton(
                                tooltip: 'Copy message',
                                onPressed: () =>
                                    copyText(context, displayText),
                                icon:
                                    const Icon(Icons.copy_rounded, size: 17),
                                color: AppColors.textMuted,
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (widget.timestamp != null)
                              Text(
                                isToday ? timeStr : fullDateStr,
                                style: AppTypography.bodySmall().copyWith(
                                  fontSize: 12,
                                  color: AppColors.textDisabled,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (widget.timestamp != null && widget.isUser)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isToday ? timeStr : fullDateStr,
                              style: AppTypography.bodySmall().copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textMuted,
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
        ],
      ),
    );
  }
}

class _AnimeMessageImages extends StatelessWidget {
  final List<String> imageUrls;

  const _AnimeMessageImages({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: imageUrls.map((url) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ClipRRect(
            borderRadius: AppRadius.radiusMd,
            child: url.startsWith('data:image')
                ? Image.memory(
                    _decodeBase64(url),
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _AnimeBrokenImageTile(),
                  )
                : AppNetworkImage(
                    imageUrl: url,
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    cacheWidth: 540,
                    errorWidget: _AnimeBrokenImageTile(),
                  ),
          ),
        );
      }).toList(),
    );
  }
}

class _AnimeBrokenImageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      color: AppColors.velvet.withValues(alpha: 0.6),
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textDisabled,
        size: 28,
      ),
    );
  }
}

class _AnimeMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const _AnimeMarkdownText({required this.text, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    return EverglowMarkdown(
      text: text,
      plain: true,
      baseStyle: baseStyle ??
          AppTypography.bodyMedium().copyWith(
            fontFamily: AppTypography.reading,
            fontWeight: FontWeight.w400,
            color: AppColors.textHigh,
            height: 1.55,
          ),
    );
  }
}

class _AnimeStreamingPlaceholder extends StatelessWidget {
  const _AnimeStreamingPlaceholder();

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
        const _AnimeThreeDots(),
      ],
    );
  }
}

class _AnimeThreeDots extends StatefulWidget {
  const _AnimeThreeDots();

  @override
  State<_AnimeThreeDots> createState() => _AnimeThreeDotsState();
}

class _AnimeThreeDotsState extends State<_AnimeThreeDots>
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

class _AnimeAnsweringAvatar extends StatefulWidget {
  const _AnimeAnsweringAvatar({this.size = 20});

  final double size;

  @override
  State<_AnimeAnsweringAvatar> createState() => _AnimeAnsweringAvatarState();
}

class _AnimeAnsweringAvatarState extends State<_AnimeAnsweringAvatar>
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
        // Primary halo: preserves key and radial gradient color alpha animation
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
                child: _AnimeMotchiAvatar(size: widget.size),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Animated badge beside Motchi's name showing she is replying / thinking.
class _AnimeReplyingBadge extends StatefulWidget {
  final bool isThinking;
  const _AnimeReplyingBadge({this.isThinking = false});

  @override
  State<_AnimeReplyingBadge> createState() => _AnimeReplyingBadgeState();
}

class _AnimeReplyingBadgeState extends State<_AnimeReplyingBadge>
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

class _AnimeStreamingCaret extends StatefulWidget {
  const _AnimeStreamingCaret();

  @override
  State<_AnimeStreamingCaret> createState() => _AnimeStreamingCaretState();
}

class _AnimeStreamingCaretState extends State<_AnimeStreamingCaret>
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
class _AnimeStreamingTailIndicator extends StatelessWidget {
  const _AnimeStreamingTailIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AnimeStreamingCaret(),
        SizedBox(width: 7),
        _AnimeStreamingDotsWave(),
      ],
    );
  }
}

/// Three micro-dots doing a gentle wave while Motchi generates text.
class _AnimeStreamingDotsWave extends StatefulWidget {
  const _AnimeStreamingDotsWave();

  @override
  State<_AnimeStreamingDotsWave> createState() =>
      _AnimeStreamingDotsWaveState();
}

class _AnimeStreamingDotsWaveState extends State<_AnimeStreamingDotsWave>
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

class _AnimeThinkingIndicator extends StatelessWidget {
  const _AnimeThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _AnimeAnsweringAvatar(size: 20),
              const SizedBox(width: 8),
              Text(
                'Motchi',
                style: AppTypography.bodySmall().copyWith(
                  fontFamily: AppTypography.reading,
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(width: 8),
              const _AnimeReplyingBadge(isThinking: true),
            ],
          ),
          const SizedBox(height: 12),
          const _AnimeStreamingPlaceholder(),
        ],
      ),
    );
  }
}

class _AnimeLiveToolStrip extends StatefulWidget {
  final AIService ai;
  const _AnimeLiveToolStrip({required this.ai});

  @override
  State<_AnimeLiveToolStrip> createState() => _AnimeLiveToolStripState();
}

class _AnimeLiveToolStripState extends State<_AnimeLiveToolStrip> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _followNewest() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if ((_scroll.offset - max).abs() > 1) {
      _scroll.animateTo(
        max,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: widget.ai.activeToolsNotifier,
      builder: (context, tools, _) {
        if (tools.isEmpty) return const SizedBox.shrink();
        WidgetsBinding.instance.addPostFrameCallback((_) => _followNewest());
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tools.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: _AnimeToolStatusChip(
                      key: ValueKey(tools[i]),
                      status: tools[i],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimeToolStatusChip extends StatefulWidget {
  final String status;

  const _AnimeToolStatusChip({super.key, required this.status});

  @override
  State<_AnimeToolStatusChip> createState() => _AnimeToolStatusChipState();
}

class _AnimeToolStatusChipState extends State<_AnimeToolStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _animeToolAccent(widget.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: accent.withValues(alpha: 0.32), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Opacity(
              opacity: 0.45 + 0.55 * _c.value,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Icon(_animeToolIcon(widget.status), size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            _animeFormatToolStatus(widget.status),
            style: AppTypography.bodySmall().copyWith(
              fontSize: 11.5,
              color: AppColors.petalWhite,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimeWebSourcesCard extends StatelessWidget {
  final List<Map<String, String>> sources;
  const _AnimeWebSourcesCard({required this.sources});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    const accent = AppColors.auroraTeal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.inkDeep.withValues(alpha: 0.90),
            AppColors.velvet.withValues(alpha: 0.70),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  size: 12,
                  color: accent,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'MOTCHI\'S DISCOVERIES',
                style: AppTypography.labelSmall().copyWith(
                  fontSize: 10,
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sources.length}',
                  style: AppTypography.labelSmall().copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sources.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return _AnimeWebSourceTile(
                  index: i + 1,
                  title: sources[i]['title'] ?? '',
                  url: sources[i]['url'] ?? '',
                  site: sources[i]['site'] ?? '',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimeWebSourceTile extends StatefulWidget {
  final int index;
  final String title;
  final String url;
  final String site;

  const _AnimeWebSourceTile({
    required this.index,
    required this.title,
    required this.url,
    required this.site,
  });

  @override
  State<_AnimeWebSourceTile> createState() => _AnimeWebSourceTileState();
}

class _AnimeWebSourceTileState extends State<_AnimeWebSourceTile> {
  bool _hover = false;

  String _cleanHost(String site, String url) {
    var s = site.trim();
    if (s.isEmpty) {
      s = Uri.tryParse(url)?.host ?? '';
    }
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.replaceFirst(RegExp(r'^www\.'), '');
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.isEmpty ? 'source' : s;
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.auroraTeal;
    final host = _cleanHost(widget.site, widget.url);
    final displayTitle = widget.title.isNotEmpty ? widget.title : host;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _animeOpenWebSource(widget.url);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: _hover
                ? AppColors.inkDeep.withValues(alpha: 0.95)
                : AppColors.velvet.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _hover
                  ? accent.withValues(alpha: 0.50)
                  : accent.withValues(alpha: 0.20),
              width: 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${widget.index}',
                      style: AppTypography.labelSmall().copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      host,
                      style: AppTypography.bodySmall().copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: accent.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 13,
                    color: _hover ? accent : AppColors.textMuted,
                  ),
                ],
              ),
              Text(
                displayTitle,
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.petalWhite,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a source link outside Everglow. Failures stay silent — a dead
/// link is not worth an error banner in the middle of Clair's chat.
Future<void> _animeOpenWebSource(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

String _animeFormatToolStatus(String status) {
  if (status == 'generating') return 'Motchi is thinking... 🍡';
  if (status == 'thinking') return 'Motchi is thinking... 🍡';
  if (status == 'executing') return 'Motchi is working on it... 🐾';
  if (status == 'done') return 'Motchi is done ✨';
  if (status == 'request_tools') return 'Motchi is getting ready... 🐾';
  if (status.startsWith('round_')) return 'Motchi is thinking... 🍡';
  const toolNames = {
    'request_tools': 'Getting ready... 🐾',
    'propose_choices': 'Picking choices... 🎴',
    'add_to_watchlist': 'Adding to watchlist... 🍿',
    'save_to_starlight_jar': 'Saving to Starlight Jar... ✨',
    'read_starlight_jar': 'Reading the Starlight Jar... 🌟',
    'set_mood': 'Logging mood... 💖',
    'search_movies': 'Checking cinema tickets... 🎬',
    'get_watchlist': 'Reading the watchlist... 🍿',
    'get_weather': 'Sniffing the breeze... ⛅',
    'create_reminder': 'Writing a sticky note... 📝',
    'log_activity': 'Logging activity... 🐾',
    'search_books': 'Browsing book shelves... 📚',
    'add_book_to_our_books': 'Adding to Our Books... 📖',
    'get_date_ideas': 'Dreaming up date ideas... 💕',
    'read_chat_messages': 'Reading chat messages... 💬',
    'send_sanctuary_message': 'Sending to Sanctuary... 💌',
    'get_xp_stats': 'Checking XP stats... ⭐',
    'search_anime': 'Searching anime... 🌸',
    'remember_fact': 'Tucking into memory... 🧠',
    'read_memories': 'Flipping through memories... 📖',
    'pin_memory': 'Pinning memory... 📌',
    'delete_memory': 'Forgetting that... 🍃',
    'edit_memory': 'Updating memory... ✏️',
    'mark_watchlist_item_watched': 'Marking as watched... 🎬',
    'update_book_progress': 'Updating book progress... 🔖',
    'add_xp': 'Awarding XP... ⭐',
    'send_note_to_partner': 'Sending a love note... 💌',
    'get_relationship_insights': 'Finding love patterns... 🐾',
    'get_memory_trivia': 'Making memory trivia... 💡',
    'get_today_recap': 'Compiling today... ☀️',
    'get_gallery': 'Browsing our photos... 📷',
    'get_garden': 'Visiting the garden... 🌸',
    'get_canvas': 'Looking at drawings... 🎨',
    'search_spotify': 'Tuning into Spotify... 🎵',
    'remove_from_watchlist': 'Removing from watchlist... 🍿',
    'search_everglow': 'Searching Everglow... 🐾',
    'plan_date_night': 'Planning date night... 🥂',
    'add_calendar_event': 'Marking the calendar... 📅',
    'create_journal_entry': 'Writing in diary... 📔',
    'add_bucket_item': 'Adding to bucket list... 🎯',
    'add_trip': 'Planning our getaway... ✈️',
    'add_trip_pin': 'Pinning trip spot... 📍',
    'log_habit': 'Tracking habit... 🐾',
    'complete_habit': 'Completing habit... 🎉',
    'get_calendar_events': 'Checking the calendar... 📅',
    'get_bucket_list': 'Reading bucket list... 🎯',
    'get_journal_entries': 'Reading our diary... 📔',
    'search_journal_entries': 'Searching journal... 🔍',
    'read_journal_entry': 'Reading journal entry... 📖',
    'get_trips': 'Reading our trips... ✈️',
    'web_search': 'Sniffing the web... 🌐🐾',
    'read_web_page': 'Reading webpage... 📄🐾',
    'browse_web': 'Browsing live... 🐾',
    'list_reminders': 'Checking sticky notes... 📋',
    'cancel_reminder': 'Dropping reminder... 🗑️',
    'edit_journal_entry': 'Editing journal... ✏️',
    'delete_journal_entry': 'Deleting journal entry... 🗑️',
    'update_calendar_event': 'Updating calendar... 📅',
    'delete_calendar_event': 'Removing calendar event... 🗑️',
    'complete_bucket_item': 'Checking off bucket item... ✅',
    'delete_bucket_item': 'Removing bucket item... 🗑️',
  };
  return toolNames[status] ?? status.replaceAll('_', ' ');
}

IconData _animeToolIcon(String status) {
  switch (status) {
    case 'request_tools':
      return Icons.pets_rounded;
    case 'propose_choices':
      return Icons.touch_app_rounded;
    case 'add_to_watchlist':
      return Icons.playlist_add_rounded;
    case 'save_to_starlight_jar':
      return Icons.auto_awesome_rounded;
    case 'read_starlight_jar':
      return Icons.auto_awesome_outlined;
    case 'set_mood':
      return Icons.mood_rounded;
    case 'search_movies':
      return Icons.movie_outlined;
    case 'get_watchlist':
      return Icons.video_library_outlined;
    case 'get_weather':
      return Icons.cloud_outlined;
    case 'create_reminder':
      return Icons.alarm_add_rounded;
    case 'log_activity':
      return Icons.bolt_rounded;
    case 'search_books':
      return Icons.menu_book_outlined;
    case 'add_book_to_our_books':
      return Icons.library_add_outlined;
    case 'get_date_ideas':
      return Icons.calendar_month_outlined;
    case 'read_chat_messages':
      return Icons.forum_outlined;
    case 'send_sanctuary_message':
      return Icons.send_rounded;
    case 'get_xp_stats':
      return Icons.military_tech_rounded;
    case 'search_anime':
      return Icons.animation_rounded;
    case 'remember_fact':
      return Icons.bookmark_add_outlined;
    case 'read_memories':
      return Icons.menu_book_outlined;
    case 'pin_memory':
      return Icons.push_pin_rounded;
    case 'delete_memory':
      return Icons.delete_outline_rounded;
    case 'edit_memory':
      return Icons.edit_note_rounded;
    case 'mark_watchlist_item_watched':
      return Icons.check_circle_outline_rounded;
    case 'update_book_progress':
      return Icons.trending_up_rounded;
    case 'add_xp':
      return Icons.military_tech_rounded;
    case 'send_note_to_partner':
      return Icons.favorite_border_rounded;
    case 'get_relationship_insights':
      return Icons.psychology_rounded;
    case 'get_memory_trivia':
      return Icons.quiz_outlined;
    case 'get_today_recap':
      return Icons.wb_twilight_rounded;
    case 'get_gallery':
      return Icons.photo_library_rounded;
    case 'get_garden':
      return Icons.local_florist_rounded;
    case 'get_canvas':
      return Icons.brush_rounded;
    case 'search_spotify':
      return Icons.music_note_rounded;
    case 'remove_from_watchlist':
      return Icons.playlist_remove_rounded;
    case 'search_everglow':
      return Icons.search_rounded;
    case 'plan_date_night':
      return Icons.event_available_rounded;
    case 'add_calendar_event':
      return Icons.event_rounded;
    case 'create_journal_entry':
      return Icons.edit_note_rounded;
    case 'add_bucket_item':
      return Icons.checklist_rounded;
    case 'add_trip':
      return Icons.flight_takeoff_rounded;
    case 'add_trip_pin':
      return Icons.pin_drop_rounded;
    case 'log_habit':
      return Icons.self_improvement_rounded;
    case 'complete_habit':
      return Icons.check_circle_rounded;
    case 'get_calendar_events':
      return Icons.calendar_month_rounded;
    case 'get_bucket_list':
      return Icons.star_rounded;
    case 'get_journal_entries':
      return Icons.book_rounded;
    case 'search_journal_entries':
      return Icons.search_rounded;
    case 'read_journal_entry':
      return Icons.auto_stories_rounded;
    case 'get_trips':
      return Icons.map_rounded;
    case 'web_search':
      return Icons.public_rounded;
    case 'read_web_page':
      return Icons.article_outlined;
    case 'browse_web':
      return Icons.travel_explore_rounded;
    case 'list_reminders':
      return Icons.notifications_outlined;
    case 'cancel_reminder':
      return Icons.alarm_off_rounded;
    case 'edit_journal_entry':
      return Icons.edit_note_rounded;
    case 'delete_journal_entry':
      return Icons.delete_outline_rounded;
    case 'update_calendar_event':
      return Icons.event_repeat_rounded;
    case 'delete_calendar_event':
      return Icons.event_busy_rounded;
    case 'complete_bucket_item':
      return Icons.check_circle_rounded;
    case 'delete_bucket_item':
      return Icons.delete_outline_rounded;
    default:
      return Icons.auto_fix_high_rounded;
  }
}

Color _animeToolAccent(String status) {
  switch (status) {
    case 'add_to_watchlist':
    case 'search_movies':
    case 'get_watchlist':
    case 'search_anime':
    case 'search_spotify':
    case 'search_everglow':
      return AppColors.blushGold;
    case 'save_to_starlight_jar':
    case 'read_starlight_jar':
    case 'get_gallery':
    case 'get_canvas':
      return AppColors.auroraLilac;
    case 'set_mood':
    case 'get_weather':
    case 'get_garden':
      return AppColors.auroraTeal;
    case 'get_date_ideas':
    case 'remember_fact':
    case 'read_memories':
    case 'pin_memory':
    case 'delete_memory':
    case 'edit_memory':
    case 'get_memory_trivia':
    case 'get_today_recap':
    case 'plan_date_night':
      return AppColors.roseQuartz;
    case 'add_calendar_event':
      return AppColors.auroraTeal;
    case 'create_journal_entry':
      return AppColors.auroraLilac;
    case 'add_bucket_item':
      return AppColors.blushGold;
    case 'add_trip':
    case 'add_trip_pin':
      return AppColors.auroraTeal;
    case 'log_habit':
    case 'complete_habit':
      return AppColors.roseQuartz;
    case 'get_calendar_events':
    case 'get_bucket_list':
    case 'get_journal_entries':
    case 'search_journal_entries':
    case 'read_journal_entry':
    case 'get_trips':
    case 'list_reminders':
    case 'cancel_reminder':
      return AppColors.textMuted;
    case 'web_search':
    case 'read_web_page':
    case 'browse_web':
      return AppColors.auroraTeal;
    case 'edit_journal_entry':
    case 'delete_journal_entry':
    case 'update_calendar_event':
    case 'delete_calendar_event':
    case 'complete_bucket_item':
    case 'delete_bucket_item':
      return AppColors.auroraRose;
    case 'mark_watchlist_item_watched':
    case 'update_book_progress':
    case 'add_xp':
    case 'remove_from_watchlist':
      return AppColors.auroraTeal;
    case 'send_note_to_partner':
    case 'send_sanctuary_message':
    case 'get_relationship_insights':
      return AppColors.auroraLilac;
    default:
      return AppColors.blushGold;
  }
}

final Map<String, Uint8List> _animeBase64Cache = <String, Uint8List>{};

Uint8List _decodeBase64(String dataUri) {
  final cached = _animeBase64Cache[dataUri];
  if (cached != null) return cached;
  final base64Str = dataUri.split(',').last;
  final decoded = Uint8List.fromList(base64Decode(base64Str));
  if (_animeBase64Cache.length >= 64) {
    _animeBase64Cache.remove(_animeBase64Cache.keys.first);
  }
  _animeBase64Cache[dataUri] = decoded;
  return decoded;
}

/// Floating trigger button anchored on the right/bottom-right of the Anime section.
class AnimeXMotchiFloatingTrigger extends StatelessWidget {
  final VoidCallback onTap;

  const AnimeXMotchiFloatingTrigger({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Chat with Motchi',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E1E2C),
                Color(0xFF13131D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.7),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.blushGold.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.blushGold,
                    width: 1.2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/motchi_avatar.webp',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Motchi',
                style: AppTypography.bodyMedium().copyWith(
                  color: AppColors.petalWhite,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: AppColors.blushGold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
