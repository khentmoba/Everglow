import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../../../../shared/widgets/app_network_image.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/study_artifact.dart';
import '../../domain/models/ai_conversation.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/utils/text_utils.dart';
import '../../../../shared/utils/greeting_utils.dart';

import '../../../../shared/widgets/everglow/everglow_chat_bubble.dart';
import '../../../../shared/widgets/everglow/everglow_markdown.dart';
import '../../domain/motchi_quality.dart';
import '../../domain/motchi_reply_details.dart';
import 'motchi_reply_details_card.dart';
import '../../../books/data/services/web_tts_service.dart';
import 'motchi_web_bridge.dart';
import 'motchi_sidebar.dart';
import 'study_artifact_sheet.dart';
import 'package:everglow/core/perf/perf_settings.dart';
part 'motchi_widgets.dart';
part 'motchi_widgets_streaming.dart';
part 'motchi_widgets_extra.dart';
part 'motchi_widgets_markdown.dart';
part 'motchi_widgets_tools.dart';

enum DeepThinkMode { auto, on, off }

class MotchiScreen extends StatefulWidget {
  const MotchiScreen({super.key});

  @override
  State<MotchiScreen> createState() => _MotchiScreenState();
}

class _MotchiScreenState extends State<MotchiScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _inputKey = GlobalKey();
  bool _showScrollButton = false;
  bool _isSending = false;
  bool _conversationLoading = true;
  bool _conversationFailed = false;
  bool _startingChat = false;
  bool _userScrolledUp = false;
  bool _scrollingToBottom = false;
  DeepThinkMode _deepThinkMode = DeepThinkMode.auto;
  // Canvas toggle — when off, Motchi just chats normally instead of making
  // interactive quizzes / cards / games proactively. Defaults OFF so quick
  // questions stay plain chat. An explicit ask ("make chess", "quiz us")
  // auto-turns it on for that request; past artifacts always stay visible.
  bool _canvasEnabled = false;
  String? _lastSentMessage;
  bool _isSidebarOpen = false;
  bool _sidebarInitialized = false;
  final List<String> _attachedImages = [];
  final List<String> _attachedImageUrls = [];
  final ImagePicker _picker = ImagePicker();
  final MotchiWebBridge _webBridge = MotchiWebBridge();
  AIService? _aiService;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _webBridge.installPasteListener(_onPastedImage);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ai = context.read<AIService>();
      _aiService = ai;
      ai.addListener(_onAiChanged);
      ai.draftResponseNotifier.addListener(_onDraft);
      ai.toolResultsNotifier.addListener(_onToolResults);
      await _loadConversation();
    });
  }

  Future<void> _loadConversation() async {
    setState(() {
      _conversationLoading = true;
      _conversationFailed = false;
    });
    try {
      await context.read<AIService>().loadAssistantConversation();
      if (!mounted) return;
      setState(() => _conversationLoading = false);
      _scrollToBottom(animated: false);
    } catch (error) {
      Logger.e('Motchi conversation failed to load', error: error);
      if (!mounted) return;
      setState(() {
        _conversationLoading = false;
        _conversationFailed = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _aiService ??= context.read<AIService>();
    if (!_sidebarInitialized) {
      _isSidebarOpen = MediaQuery.sizeOf(context).width >= 1024;
      _sidebarInitialized = true;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _focusNode.dispose();
    final ai = _aiService;
    if (ai != null) {
      ai.draftResponseNotifier.removeListener(_onDraft);
      ai.toolResultsNotifier.removeListener(_onToolResults);
      ai.removeListener(_onAiChanged);
    }
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
    if (!_scrollingToBottom) {
      _userScrolledUp =
          _scroll.hasClients &&
          _scroll.position.maxScrollExtent - _scroll.position.pixels > 120;
    }
    final show =
        _scroll.hasClients &&
        _scroll.position.maxScrollExtent - _scroll.position.pixels > 300;
    if (show != _showScrollButton) {
      setState(() => _showScrollButton = show);
    }
  }

  static const _undoableDeleteTools = {
    'delete_memory',
    'remove_from_watchlist',
    'delete_calendar_event',
    'delete_journal_entry',
    'delete_bucket_item',
  };

  String _restoreMessage(Map<String, dynamic> last) {
    final tool = last['tool'] as String? ?? '';
    if (tool == 'delete_memory') {
      return 'Please remember this again: ${last['fact'] ?? ''}';
    }
    if (tool == 'remove_from_watchlist') {
      final title = last['title'] ?? '';
      return 'Please add "$title" back to our watchlist';
    }
    final deleted = last['deleted'];
    final detail = deleted is Map
        ? deleted.entries
              .where((e) => e.value != null && '${e.value}'.isNotEmpty)
              .map((e) => '${e.key}: ${e.value}')
              .join(', ')
        : '${last['title'] ?? ''}';
    if (tool == 'delete_calendar_event') {
      return 'Please recreate this calendar event ($detail)';
    }
    if (tool == 'delete_journal_entry') {
      return 'Please recreate this journal entry ($detail)';
    }
    return 'Please add this back to our bucket list ($detail)';
  }

  void _onToolResults() {
    if (!mounted) return;
    final ai = context.read<AIService>();
    final results = ai.toolResultsNotifier.value;
    if (results.isEmpty) return;
    final last = results.last;
    if (last['success'] == true &&
        _undoableDeleteTools.contains(last['tool'])) {
      final title =
          last['fact'] as String? ?? last['title'] as String? ?? 'item';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Removed "${title.length > 30 ? '${title.substring(0, 30)}…' : title}" — tap Undo to restore',
            style: AppTypography.bodySmall(),
          ),
          backgroundColor: AppColors.velvet,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          margin: const EdgeInsets.all(AppSpacing.lg),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.blushGold,
            onPressed: () {
              final message = _restoreMessage(last);
              if (message.isNotEmpty) _sendQuick(message);
            },
          ),
        ),
      );
    }
    if (last['needs_confirmation'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            last['message'] as String? ??
                'Motchi needs your confirmation to proceed',
            style: AppTypography.bodySmall(),
          ),
          backgroundColor: AppColors.panelGlass,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          margin: const EdgeInsets.all(AppSpacing.lg),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _onDraft() {
    if (!_userScrolledUp) _scrollToBottom(animated: false);
  }

  void _onAiChanged() {
    if (!mounted) return;
    final ai = context.read<AIService>();
    if (ai.isLoading && !_userScrolledUp) {
      _scrollToBottom(animated: false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scrollingToBottom = true;
        if (animated) {
          await _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
          if (!mounted || !_scrollingToBottom) return;
          _scrollingToBottom = false;
          if (!_userScrolledUp) _scrollToBottom(animated: false);
        } else {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
          _scrollingToBottom = false;
        }
      }
    });
  }

  Future<void> _send({bool retry = false}) async {
    if (_isSending ||
        _conversationLoading ||
        _conversationFailed ||
        _startingChat ||
        context.read<AIService>().isNavigating) {
      return;
    }
    final lastReply = context
        .read<AIService>()
        .assistantConversation
        ?.messages
        .lastOrNull;
    final text = retry && lastReply?.details.steps.isNotEmpty == true
        ? 'Help finish only the unfinished steps from my last request: ${_lastSentMessage ?? ''}. Check existing records for any unconfirmed action first; do not repeat completed saves or sends.'
        : retry
        ? (_lastSentMessage ?? '').trim()
        : _input.text.trim();
    final hasImages = !retry && _attachedImageUrls.isNotEmpty;
    if (text.isEmpty && !hasImages) return;
    // Explicit artifact asks turn Canvas on so the game/quiz actually builds.
    final autoCanvas = !_canvasEnabled && motchiWantsArtifact(text);
    _isSending = true;
    _lastSentMessage = text;
    _input.clear();
    if (mounted) {
      setState(() {
        if (autoCanvas) {
          _canvasEnabled = true;
        }
      });
    }
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
      final bool enableThinking;
      switch (_deepThinkMode) {
        case DeepThinkMode.auto:
          enableThinking = const MotchiQuality().shouldAutoThink(text);
          break;
        case DeepThinkMode.on:
          enableThinking = true;
          break;
        case DeepThinkMode.off:
          enableThinking = false;
          break;
      }
      await aiService.sendMessage(
        feature: 'assistant',
        message: text,
        callerName: authService.currentUser,
        stream: true,
        canvasEnabled: _canvasEnabled,
        enableThinking: enableThinking,
        imageUrls: imagesToSend,
      );
      if (mounted) {
        setState(() {
          _lastSentMessage = null;
        });
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Error already surfaced via AIService.lastError -> _ErrorBanner; avoid duplicate SnackBar covering composer.
      debugPrint('[Motchi] send failed: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _selectDeepThink(DeepThinkMode mode) {
    HapticFeedback.lightImpact();
    setState(() => _deepThinkMode = mode);
  }

  void _preparePrompt(String text) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focusNode.requestFocus();
  }

  void _sendQuick(String text) {
    if (_startingChat || context.read<AIService>().isNavigating) return;
    _input.text = text;
    _send();
  }

  void _stop() {
    context.read<AIService>().cancelCurrentReply();
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        for (final image in images) {
          final bytes = await image.readAsBytes();
          final base64Data = bytes.length > 300 * 1024
              ? await _resizeImageToDataUri(bytes)
              : 'data:image/${image.name.split('.').last};base64,${base64Encode(bytes)}';
          if (!mounted) return;
          setState(() {
            _attachedImages.add(base64Data);
            _attachedImageUrls.add(base64Data);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to attach images: $e',
              style: AppTypography.bodySmall(),
            ),
            backgroundColor: AppColors.deepRose.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  Future<String> _resizeImageToDataUri(
    Uint8List bytes, {
    int maxDim = 1280,
  }) async {
    return _webBridge.resizeImageToDataUri(bytes, maxDim: maxDim);
  }

  void _removeImage(int index) {
    setState(() {
      _attachedImages.removeAt(index);
      _attachedImageUrls.removeAt(index);
    });
  }

  void _newChat() async {
    final ai = context.read<AIService>();
    if (ai.isLoading ||
        ai.isNavigating ||
        _isSending ||
        _startingChat ||
        _conversationLoading ||
        _conversationFailed) {
      return;
    }
    setState(() => _startingChat = true);
    try {
      await ai.clearConversation('assistant', archive: true);
      if (!mounted) return;
      _input.clear();
      setState(() {
        _attachedImages.clear();
        _attachedImageUrls.clear();
        _lastSentMessage = null;
        _userScrolledUp = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start new chat: $e',
              style: AppTypography.bodySmall(),
            ),
            backgroundColor: AppColors.deepRose.withValues(alpha: 0.9),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
    if (!mounted) return;
    setState(() => _isSidebarOpen = false);
    _scrollToBottom(animated: false);
  }

  void _onSessionOpened() {
    setState(() {
      _conversationFailed = false;
      _userScrolledUp = false;
    });
    _scrollToBottom(animated: false);
  }

  Future<void> _signInFromPreview() async {
    final auth = context.read<AuthService>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    AgentMode.disable();
    // Clear the agent query before logout notifies the router.
    router.go('/?from=%2Fmotchi');
    try {
      await auth.logout();
    } catch (error) {
      Logger.e('Motchi preview sign-in failed', error: error);
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn’t open sign-in. Please reload and try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final navigating = context.select<AIService, bool>((ai) => ai.isNavigating);
    final isPreview = context.select<AuthService, bool>(
      (auth) => auth.isAgentSession,
    );
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: SafeArea(
        child: Stack(
          children: [
            ExcludeFocus(
              excluding: !isDesktop && _isSidebarOpen,
              child: ExcludeSemantics(
                excluding: !isDesktop && _isSidebarOpen,
                child: Row(
                  children: [
                    if (isDesktop)
                      AnimatedContainer(
                        duration: AppMotion.medium,
                        curve: AppMotion.drawer,
                        width: _isSidebarOpen ? 320 : 0,
                        child: OverflowBox(
                          maxWidth: 320,
                          minWidth: 320,
                          alignment: Alignment.centerLeft,
                          child: IgnorePointer(
                            ignoring: !_isSidebarOpen,
                            child: AnimatedOpacity(
                              duration: AppMotion.fast,
                              opacity: _isSidebarOpen ? 1 : 0,
                              child: ExcludeFocus(
                                excluding: !_isSidebarOpen,
                                child: ExcludeSemantics(
                                  excluding: !_isSidebarOpen,
                                  child: MotchiSidebar(
                                    isOpen: true,
                                    onClose: () =>
                                        setState(() => _isSidebarOpen = false),
                                    onNewChat: _newChat,
                                    navigationBusy:
                                        _conversationLoading ||
                                        _startingChat ||
                                        navigating,
                                    onSessionOpened: _onSessionOpened,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          Selector<AIService, bool>(
                            selector: (_, ai) => ai.isLoading,
                            builder: (_, loading, _) => _MotchiHeader(
                              onBack: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/dashboard'),
                              onSidebarToggle: () => setState(
                                () => _isSidebarOpen = !_isSidebarOpen,
                              ),
                              onNewChat:
                                  loading ||
                                      navigating ||
                                      _startingChat ||
                                      _conversationLoading ||
                                      _conversationFailed
                                  ? null
                                  : _newChat,
                              sidebarOpen: _isSidebarOpen,
                            ),
                          ),
                          if (isPreview)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign in for real Motchi replies.',
                                    style: AppTypography.bodyMedium(),
                                  ),
                                  TextButton.icon(
                                    onPressed: _signInFromPreview,
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(48, 48),
                                      visualDensity: VisualDensity.standard,
                                    ),
                                    icon: const Icon(Icons.login_rounded),
                                    label: const Text('Sign in to chat'),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(child: _buildChatList(centered: isDesktop)),
                          _ErrorBanner(
                            lastSentMessage: _lastSentMessage,
                            onRetry: () => _send(retry: true),
                          ),
                          _ComposerInput(
                            inputKey: _inputKey,
                            enabled:
                                !isPreview &&
                                !_conversationLoading &&
                                !_conversationFailed &&
                                !_startingChat &&
                                !navigating,
                            controller: _input,
                            focusNode: _focusNode,
                            onSend: _send,
                            onStop: _stop,
                            onPickImages: _pickImages,
                            attachedImages: _attachedImages,
                            onRemoveImage: _removeImage,
                            centered: isDesktop,
                            deepThinkMode: _deepThinkMode,
                            onSelectDeepThink: _selectDeepThink,
                            canvasEnabled: _canvasEnabled,
                            onToggleCanvas: () => setState(
                              () => _canvasEnabled = !_canvasEnabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isDesktop)
              MotchiSidebar(
                isOpen: _isSidebarOpen,
                onClose: () => setState(() => _isSidebarOpen = false),
                onNewChat: _newChat,
                navigationBusy:
                    _conversationLoading || _startingChat || navigating,
                onSessionOpened: _onSessionOpened,
              ),
          ],
        ),
      ),
    );
  }

  /// Text of the nearest user message before [beforeIndex], or '' when
  /// none. Lets an assistant bubble know what was actually asked — e.g.
  /// whether the user explicitly wanted the quiz questions inline.
  String _prevUserText(List<AIMessage> msgs, int beforeIndex) {
    for (var k = beforeIndex - 1; k >= 0; k--) {
      if (msgs[k].role == 'user') return msgs[k].content;
    }
    return '';
  }

  Widget _buildChatList({required bool centered}) {
    if (_conversationLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.roseQuartz,
          strokeWidth: 2,
          semanticsLabel: 'Loading your conversation',
        ),
      );
    }
    if (_conversationFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your conversation couldn’t load.',
                style: AppTypography.titleMedium(),
              ),
              const SizedBox(height: 8),
              Text(
                'Try again to pick up where you left off.',
                style: AppTypography.bodyMedium(),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _loadConversation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Selector<AIService, (AIConversation?, int, bool)>(
          selector: (_, ai) => (
            ai.assistantConversation,
            ai.assistantConversation?.messages.length ?? 0,
            ai.isLoading,
          ),
          builder: (context, snapshot, _) {
            final ai = context.read<AIService>();
            final callerName = context.read<AuthService>().currentUser;
            final allMsgs = snapshot.$1?.messages ?? const <AIMessage>[];
            final loading = snapshot.$3;
            final busy = loading || ai.isNavigating || _startingChat;

            if (allMsgs.isEmpty && !loading) {
              return _GreetingEmptyState(
                onTap: _preparePrompt,
                centered: centered,
                callerName: callerName,
              );
            }

            final itemCount = allMsgs.length + (loading ? 1 : 0);

            Widget list = ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.symmetric(
                horizontal: centered ? 24 : 16,
                vertical: 20,
              ),
              itemCount: itemCount,
              itemBuilder: (_, i) {
                if (i == allMsgs.length) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ValueListenableBuilder<int>(
                          valueListenable: ai.draftRevisionNotifier,
                          builder: (context, _, _) {
                            final hasStream =
                                ai.draftResponse.isNotEmpty ||
                                ai.draftReasoning.isNotEmpty ||
                                ai.activeTools.isNotEmpty ||
                                ai.toolResultsNotifier.value.isNotEmpty;
                            if (hasStream) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _MessageBubble(
                                    text: MotchiReplyDetails.visibleText(
                                      ai.draftResponse,
                                    ),
                                    isUser: false,
                                    isStreaming: true,
                                    // Always show: if Motchi emitted a block, Clair asked for it.
                                    // The toggle gates *generation*, never display of past games.
                                    showArtifacts: true,
                                    keepFullText: userAskedForVisibleQuiz(
                                      _prevUserText(allMsgs, allMsgs.length),
                                    ),
                                    reasoning: ai.draftReasoning.isNotEmpty
                                        ? ai.draftReasoning
                                        : null,
                                  ),
                                  _LiveToolStrip(ai: ai),
                                  if (ai.toolResults.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: MotchiReplyDetailsCard(
                                        details: MotchiReplyDetails.fromResults(
                                          ai.toolResults,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _ThinkingIndicator(),
                                _LiveToolStrip(ai: ai),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }
                final msg = allMsgs[i];
                final isUserMsg = msg.role == 'user';
                Widget bubble = _MessageBubble(
                  key: ValueKey(
                    'msg_${msg.timestamp.millisecondsSinceEpoch}_$i',
                  ),
                  text: msg.content,
                  isUser: isUserMsg,
                  // Always show past artifacts — turning Canvas off must not
                  // hide games/quizzes Motchi already made.
                  showArtifacts: true,
                  keepFullText:
                      !isUserMsg &&
                      userAskedForVisibleQuiz(_prevUserText(allMsgs, i)),
                  timestamp: msg.timestamp,
                  imageUrls: msg.imageUrls,
                  onUseAsDraft: isUserMsg && !busy && msg.content.isNotEmpty
                      ? () => _preparePrompt(msg.content)
                      : null,
                );
                // Web answers keep their tappable sources under the
                // finished bubble (persisted on the message).
                if (!isUserMsg && msg.sources.isNotEmpty) {
                  bubble = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      bubble,
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: WebSourcesCard(sources: msg.sources),
                      ),
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
                        child: MotchiReplyDetailsCard(
                          details: msg.details,
                          onOpenMemoryBook: () =>
                              context.push('/motchi-memory'),
                          onCorrectMemory: busy ? null : _sendQuick,
                          onContinue: busy
                              ? null
                              : () => _sendQuick(
                                  'Help finish only the unfinished steps from this request: ${_prevUserText(allMsgs, i)}. Check existing records for any unconfirmed action first; do not repeat completed saves or sends.',
                                ),
                        ),
                      ),
                    ],
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Align(
                      alignment: msg.role == 'user'
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: bubble,
                    ),
                  ),
                );
              },
            );

            if (centered) {
              list = ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: true),
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: false,
                  child: list,
                ),
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification &&
                    notification.direction != ScrollDirection.idle) {
                  _scrollingToBottom = false;
                  _onScroll();
                }
                return false;
              },
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) {
                  if (!_userScrolledUp &&
                      !_scrollingToBottom &&
                      (notification.metrics.maxScrollExtent -
                                  notification.metrics.pixels)
                              .abs() >
                          1) {
                    _scrollToBottom(animated: false);
                  }
                  return false;
                },
                child: list,
              ),
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
                child: FilledButton.icon(
                  onPressed: () {
                    _userScrolledUp = false;
                    _scrollToBottom();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.silk,
                    foregroundColor: AppColors.textHigh,
                    minimumSize: const Size(48, 48),
                    visualDensity: VisualDensity.standard,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusFull,
                      side: BorderSide(color: AppColors.border),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  label: const Text('Latest message'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────
