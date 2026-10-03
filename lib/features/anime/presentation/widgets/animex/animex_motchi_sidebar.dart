import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_motion.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/everglow/everglow_chat_bubble.dart';
import '../../../../ai/data/services/ai_service.dart';
import '../../../../ai/domain/models/ai_conversation.dart';
import '../../../../ai/domain/motchi_quality.dart';
import '../../../../ai/domain/motchi_reply_details.dart';
import '../../../../ai/presentation/widgets/motchi_reply_details_card.dart';
import '../../../../ai/presentation/widgets/motchi_web_bridge.dart';
import 'animex_controller.dart';
import 'animex_tokens.dart';

enum AnimeMotchiDeepThink { auto, on, off }

/// Dedicated temporary Motchi chat sidebar for the Anime section.
///
/// Features:
/// - In-memory temporary multi-turn chat (never persists to Firestore or sessions).
/// - Full Motchi agent capabilities: memories, tools, reasoning, streaming.
/// - Right-side sliding panel with responsive desktop / tablet / mobile layout.
/// - Anime-specific context & quick prompt chips.
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
  bool _userScrolledUp = false;
  bool _showScrollButton = false;
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
    _input.dispose();
    _focusNode.dispose();
    _webBridge.uninstallPasteListener();
    super.dispose();
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
    final scrolledUp = (max - cur) > 80;
    if (scrolledUp != _userScrolledUp) {
      setState(() {
        _userScrolledUp = scrolledUp;
        _showScrollButton = scrolledUp;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send({bool retry = false}) async {
    final text = retry ? _lastSentMessage ?? '' : _input.text.trim();
    if (text.isEmpty && _attachedImageUrls.isEmpty) return;

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
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
        if (mounted) {
          setState(() {
            _attachedImages.add(dataUri);
            _attachedImageUrls.add(dataUri);
          });
        }
      }
    } catch (e) {
      debugPrint('[AnimeMotchi] image pick error: $e');
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
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 900;
    final isTablet = size.width >= 600 && size.width < 900;
    final sidebarWidth = isDesktop
        ? 390.0
        : (isTablet
            ? 380.0
            : math.min(size.width * 0.90, 400.0));

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
                    decoration: const BoxDecoration(
                      color: AnimeXTokens.surface,
                      border: Border(
                        left: BorderSide(
                          color: AnimeXTokens.border,
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xD0000000),
                          blurRadius: 36,
                          offset: Offset(-8, 0),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      left: false,
                      top: false,
                      bottom: false,
                      child: Column(
                        children: [
                          _buildHeader(context),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AnimeXTokens.border,
                          ),
                          Expanded(child: _buildChatBody(userName)),
                          _buildErrorBanner(),
                          _buildComposer(context),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AnimeXTokens.surfaceRaised.withValues(alpha: 0.96),
      ),
      child: Row(
        children: [
          // Motchi Avatar with aura
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blushGold.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/motchi_avatar.webp',
                fit: BoxFit.cover,
                cacheWidth: kIsWeb ? null : 108,
                cacheHeight: kIsWeb ? null : 108,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      'Motchi',
                      style: AppTypography.titleMedium().copyWith(
                        color: AnimeXTokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blushGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.blushGold.withValues(alpha: 0.4),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        'TEMPORARY',
                        style: AppTypography.labelSmall().copyWith(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.blushGold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Anime Assistant · Unsaved session',
                  style: AppTypography.labelSmall().copyWith(
                    color: AnimeXTokens.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // DeepThink toggle
          _DeepThinkButton(
            mode: _deepThink,
            onTap: _cycleDeepThink,
          ),
          const SizedBox(width: 2),
          // New chat / Clear
          IconButton(
            icon: const Icon(
              Icons.restart_alt_rounded,
              size: 20,
              color: AnimeXTokens.textSecondary,
            ),
            tooltip: 'New Chat (clear)',
            onPressed: _clearChat,
          ),
          // Close button
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: AnimeXTokens.textPrimary,
            ),
            tooltip: 'Close sidebar',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildChatBody(String userName) {
    final ai = _ai ?? context.watch<AIService>();
    final isStreaming = _isSending && ai.isLoading;

    if (widget.messages.isEmpty && !isStreaming) {
      return _buildEmptyState(userName);
    }

    final itemCount = widget.messages.length + (isStreaming ? 1 : 0);

    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == widget.messages.length) {
              return _buildStreamingBubble(ai);
            }
            final msg = widget.messages[index];
            if (msg.role == 'user') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EverglowUserBubble(text: msg.content),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EverglowAssistantBubble(
                    text: msg.content,
                    title: 'Motchi',
                    subtitle: 'Anime Agent',
                    timeLabel: 'Motchi • temporary anime chat',
                  ),
                  if (msg.sources.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 44, top: 6),
                      child: _buildSourcesChips(msg.sources),
                    ),
                  if (!msg.details.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 44, top: 6),
                      child: MotchiReplyDetailsCard(details: msg.details),
                    ),
                ],
              ),
            );
          },
        ),
        if (_showScrollButton)
          Positioned(
            bottom: 12,
            right: 16,
            child: FloatingActionButton.small(
              backgroundColor: AnimeXTokens.surfaceRaised,
              foregroundColor: AnimeXTokens.textPrimary,
              elevation: 4,
              onPressed: () => _scrollToBottom(),
              child: const Icon(Icons.arrow_downward_rounded, size: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildStreamingBubble(AIService ai) {
    return ValueListenableBuilder<int>(
      valueListenable: ai.draftRevisionNotifier,
      builder: (context, _, _) {
        final draftText = ai.draftResponse;
        final reasoning = ai.draftReasoning;
        final hasDraft = draftText.isNotEmpty || reasoning.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDraft) ...[
                if (reasoning.isNotEmpty)
                  _CollapsibleReasoning(reasoning: reasoning),
                EverglowAssistantBubble(
                  text: MotchiReplyDetails.visibleText(draftText),
                  title: 'Motchi',
                  subtitle: 'Anime Agent',
                  isStreaming: true,
                ),
              ] else ...[
                _buildThinkingIndicator(),
              ],
              if (ai.activeTools.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 6),
                  child: _buildToolStatusChip(ai.activeTools.last),
                ),
              if (ai.toolResults.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 6),
                  child: MotchiReplyDetailsCard(
                    details: MotchiReplyDetails.fromResults(ai.toolResults),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThinkingIndicator() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.blushGold.withValues(alpha: 0.6),
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/motchi_avatar.webp',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AnimeXTokens.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AnimeXTokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.blushGold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Motchi is thinking...',
                style: AppTypography.bodySmall().copyWith(
                  color: AnimeXTokens.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolStatusChip(String toolName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inkDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(AppColors.blushGold),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatToolName(toolName),
            style: AppTypography.labelSmall().copyWith(
              color: AppColors.blushGold,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatToolName(String name) {
    switch (name) {
      case 'web_search':
        return 'Searching web...';
      case 'read_web_page':
        return 'Reading anime page...';
      case 'read_memories':
        return 'Checking couple memories...';
      case 'remember_fact':
        return 'Saving memory...';
      default:
        return 'Using $name...';
    }
  }

  Widget _buildSourcesChips(List<Map<String, String>> sources) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final s in sources)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AnimeXTokens.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AnimeXTokens.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 11,
                  color: AnimeXTokens.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  s['title'] ?? s['site'] ?? 'Source',
                  style: AppTypography.labelSmall().copyWith(
                    color: AnimeXTokens.textSecondary,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(String userName) {
    final watchItem = widget.controller.watchItem;
    final greetingName = userName.toLowerCase().contains('clair')
        ? 'Clair'
        : (userName.toLowerCase().contains('khent') ? 'Khent' : 'there');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.blushGold.withValues(alpha: 0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blushGold.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/motchi_avatar.webp',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Hi $greetingName! 🍡',
            style: AppTypography.titleLarge().copyWith(
              color: AnimeXTokens.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Your temporary anime companion! Ask me for recommendations, plot lore, character details, or anything on your mind.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall().copyWith(
                color: AnimeXTokens.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Suggested prompt chips
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SUGGESTED ASKS',
              style: AppTypography.labelSmall().copyWith(
                color: AnimeXTokens.textMuted,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (watchItem != null) ...[
            _SuggestionChip(
              icon: Icons.movie_filter_outlined,
              label: 'Tell me about "${watchItem.title}"',
              onTap: () => _sendPrompt('Tell me about the anime "${watchItem.title}" — synopsis, vibe, and why it is loved!'),
            ),
            const SizedBox(height: 6),
            _SuggestionChip(
              icon: Icons.auto_awesome_outlined,
              label: 'Recommend anime similar to this',
              onTap: () => _sendPrompt('What anime are similar in vibe and genre to "${watchItem.title}"? Give 3 recommendations.'),
            ),
            const SizedBox(height: 6),
          ],
          _SuggestionChip(
            icon: Icons.auto_awesome_rounded,
            label: '✨ Recommend an anime like Frieren',
            onTap: () => _sendPrompt('Recommend anime like Frieren: Beyond Journey\'s End with rich worldbuilding and emotional depth.'),
          ),
          const SizedBox(height: 6),
          _SuggestionChip(
            icon: Icons.favorite_border_rounded,
            label: '🌸 Top romance anime to watch together',
            onTap: () => _sendPrompt('What are the best cute, heartfelt romance anime for a couple to watch together?'),
          ),
          const SizedBox(height: 6),
          _SuggestionChip(
            icon: Icons.calendar_month_outlined,
            label: '📅 What are the best anime airing this season?',
            onTap: () => _sendPrompt('What are the most popular and highly rated anime currently airing this season?'),
          ),
          const SizedBox(height: 6),
          _SuggestionChip(
            icon: Icons.psychology_outlined,
            label: '🎭 Explain the lore of Steins;Gate',
            onTap: () => _sendPrompt('Explain the worldline and time travel mechanics of Steins;Gate simply and clearly.'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    final ai = _ai ?? context.watch<AIService>();
    if (ai.lastError == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.deepRose.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.deepRose.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.deepRose,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ai.lastError!,
              style: AppTypography.bodySmall().copyWith(
                color: AnimeXTokens.textPrimary,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_lastSentMessage != null)
            TextButton(
              onPressed: () => _send(retry: true),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AnimeXTokens.surfaceRaised,
        border: Border(
          top: BorderSide(color: AnimeXTokens.border, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachedImages.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: _attachedImages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(
                            _attachedImages[i].split(',').last,
                          ),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black87,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: AnimeXTokens.textSecondary,
                ),
                tooltip: 'Attach image',
                onPressed: _isSending ? null : _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  style: AppTypography.bodyMedium().copyWith(
                    color: AnimeXTokens.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask Motchi about anime...',
                    hintStyle: AppTypography.bodyMedium().copyWith(
                      color: AnimeXTokens.textMuted,
                      fontSize: 14,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AnimeXTokens.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AnimeXTokens.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: AppColors.blushGold.withValues(alpha: 0.6),
                      ),
                    ),
                    filled: true,
                    fillColor: AnimeXTokens.surface,
                  ),
                  onSubmitted: (_) {
                    if (!_isSending) _send();
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (_isSending)
                IconButton.filled(
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.deepRose,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Stop reply',
                  onPressed: _stop,
                )
              else
                IconButton.filled(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AnimeXTokens.accent,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Send',
                  onPressed: _send,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeepThinkButton extends StatelessWidget {
  final AnimeMotchiDeepThink mode;
  final VoidCallback onTap;

  const _DeepThinkButton({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, iconColor, bgColor) = switch (mode) {
      AnimeMotchiDeepThink.auto => (
          'Auto',
          AnimeXTokens.textSecondary,
          Colors.transparent
        ),
      AnimeMotchiDeepThink.on => (
          'Think',
          AppColors.blushGold,
          AppColors.blushGold.withValues(alpha: 0.16)
        ),
      AnimeMotchiDeepThink.off => (
          'Off',
          AnimeXTokens.textMuted,
          Colors.transparent
        ),
    };

    return Tooltip(
      message: 'DeepThink: $label (tap to change)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: mode == AnimeMotchiDeepThink.on
                  ? AppColors.blushGold.withValues(alpha: 0.5)
                  : AnimeXTokens.border,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.labelSmall().copyWith(
                  color: iconColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AnimeXTokens.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AnimeXTokens.border),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: AppColors.blushGold),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall().copyWith(
                  color: AnimeXTokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AnimeXTokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleReasoning extends StatefulWidget {
  final String reasoning;

  const _CollapsibleReasoning({required this.reasoning});

  @override
  State<_CollapsibleReasoning> createState() => _CollapsibleReasoningState();
}

class _CollapsibleReasoningState extends State<_CollapsibleReasoning> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 44, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inkDeep.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  size: 15,
                  color: AppColors.blushGold,
                ),
                const SizedBox(width: 6),
                Text(
                  'Reasoning process',
                  style: AppTypography.labelSmall().copyWith(
                    color: AppColors.blushGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AnimeXTokens.textMuted,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            SelectableText(
              widget.reasoning,
              style: AppTypography.bodySmall().copyWith(
                color: AnimeXTokens.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
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
                  color: AnimeXTokens.textPrimary,
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
