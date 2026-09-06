import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_network_image.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/study_doc_service.dart';
import '../../domain/models/ai_conversation.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/utils/text_utils.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../domain/mochi_quality.dart';
import 'mochi_web_bridge.dart';
import 'mochi_sidebar.dart';
part 'mochi_widgets.dart';
part 'mochi_widgets_streaming.dart';
part 'mochi_widgets_extra.dart';

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
  bool _userScrolledUp = false;
  bool _deepThink = true;
  bool _deepThinkTouched = false;
  String? _lastSentMessage;
  bool _isSidebarOpen = false;
  final List<String> _attachedImages = [];
  final List<String> _attachedImageUrls = [];
  final ImagePicker _picker = ImagePicker();
  final MochiWebBridge _webBridge = MochiWebBridge();
  final StudyDocService _studyDocs = StudyDocService();
  StudyDoc? _studyDoc;
  bool _studyDocSent = false;
  bool _pickingDoc = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _webBridge.installPasteListener(_onPastedImage);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ai = context.read<AIService>();
      ai.addListener(_onAiChanged);
      ai.toolResultsNotifier.addListener(_onToolResults);
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
    try {
      try { context.read<AIService>().toolResultsNotifier.removeListener(_onToolResults); } catch (_) {}
      context.read<AIService>().removeListener(_onAiChanged);
    } catch (_) {}
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
    _userScrolledUp =
        _scroll.hasClients &&
        _scroll.position.maxScrollExtent - _scroll.position.pixels > 120;
    final show =
        _scroll.hasClients &&
        _scroll.position.maxScrollExtent - _scroll.position.pixels > 300;
    if (show != _showScrollButton) {
      setState(() => _showScrollButton = show);
    }
  }

    void _onToolResults() {
    if (!mounted) return;
    final ai = context.read<AIService>();
    final results = ai.toolResultsNotifier.value;
    if (results.isEmpty) return;
    final last = results.last;
    if (last['success'] == true && (last['tool'] == 'delete_memory' || last['tool'] == 'remove_from_watchlist')) {
      final title = last['fact'] as String? ?? last['title'] as String? ?? 'item';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${title.length > 30 ? '${title.substring(0, 30)}…' : title}" — tap Undo to restore', style: AppTypography.bodySmall()),
          backgroundColor: AppColors.velvet,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          margin: const EdgeInsets.all(AppSpacing.lg),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.blushGold,
            onPressed: () {
              final fact = last['fact'] as String? ?? last['title'] as String? ?? '';
              if (fact.isNotEmpty) {
                if (last['tool'] == 'delete_memory') {
                  context.read<AIService>().sendMessage(feature: 'assistant', message: 'Please remember this again: $fact');
                } else {
                  context.read<AIService>().sendMessage(feature: 'assistant', message: 'Please add "$fact" back to our watchlist');
                }
              }
            },
          ),
        ),
      );
    }
    if (last['needs_confirmation'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(last['message'] as String? ?? 'Mochi needs your confirmation to proceed', style: AppTypography.bodySmall()),
          backgroundColor: AppColors.panelGlass,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          margin: const EdgeInsets.all(AppSpacing.lg),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _onAiChanged() {
    if (!mounted) return;
    final ai = context.read<AIService>();
    if (ai.isLoading && !_userScrolledUp) {
      _scrollToBottom(animated: false);
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

  Future<void> _send({bool retry = false}) async {
    if (_isSending) return;
    final rawText = retry ? (_lastSentMessage ?? '').trim() : _input.text.trim();
    final hasImages = !retry && _attachedImageUrls.isNotEmpty;
    final hasStudy = !retry && _studyDoc != null && !_studyDocSent;
    if (rawText.isEmpty && !hasImages && !hasStudy) return;
    _isSending = true;
    // Study doc text rides along on its first send only; after that it
    // lives in history. Retry resends the already-built message as-is.
    final text = hasStudy
        ? buildStudyMessage(doc: _studyDoc!, userPrompt: rawText)
        : rawText;
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
        if (hasStudy) _studyDocSent = true;
      });
      await aiService.sendMessage(
        feature: 'assistant',
        message: text,
        callerName: authService.currentUser,
        stream: true,
        enableThinking: _deepThinkTouched
            ? _deepThink
            : _deepThink || const MochiQuality().shouldAutoThink(text),
        imageUrls: imagesToSend,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Error already surfaced via AIService.lastError -> _ErrorBanner; avoid duplicate SnackBar covering composer.
      debugPrint('[Mochi] send failed: $e');
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

  Future<void> _pickStudyDoc() async {
    if (_pickingDoc) return;
    setState(() => _pickingDoc = true);
    try {
      final doc = await _studyDocs.pickAndExtract();
      if (!mounted || doc == null) return; // user cancelled
      setState(() {
        _studyDoc = doc;
        _studyDocSent = false;
      });
      _focusNode.requestFocus();
    } on StudyDocException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message, style: AppTypography.bodySmall()),
            backgroundColor: AppColors.deepRose.withValues(alpha: 0.9),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingDoc = false);
    }
  }

  void _removeStudyDoc() {
    setState(() {
      _studyDoc = null;
      _studyDocSent = false;
    });
  }

  void _newChat() async {
    final ai = context.read<AIService>();
    try {
      await ai.clearConversation('assistant', archive: true);
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
    }
    if (!mounted) return;
    setState(() {
      _isSidebarOpen = false;
      // Study docs live in one chat only — a new chat drops them.
      _studyDoc = null;
      _studyDocSent = false;
    });
    _scrollToBottom(animated: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    if (isDesktop) return _buildDesktop(context);
    return _buildMobile(context);
  }

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraLilac,
                  alignment: Alignment(-0.7, -0.9),
                  size: 0.9,
                  opacity: 0.14,
                ),
                RadialGlow(
                  color: AppColors.deepRose,
                  alignment: Alignment(0.9, 0.9),
                  size: 0.8,
                  opacity: 0.10,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppMotion.medium,
                  curve: AppMotion.drawer,
                  width: _isSidebarOpen ? 320 : 0,
                  child: OverflowBox(
                    maxWidth: 320,
                    minWidth: 320,
                    alignment: Alignment.centerLeft,
                    // Closed sidebar is fully transparent but still overflows
                    // 320px over the chat area — ignore its pointer events so
                    // it can't swallow taps/hovers on the suggestion cards.
                    child: IgnorePointer(
                      ignoring: !_isSidebarOpen,
                      child: AnimatedOpacity(
                        duration: AppMotion.fast,
                        opacity: _isSidebarOpen ? 1 : 0,
                        child: MochiSidebar(
                          isOpen: true,
                          onClose: () =>
                              setState(() => _isSidebarOpen = false),
                          onNewChat: _newChat,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _MochiHeader(
                        onBack: () => context.pop(),
                        onSidebarToggle: () =>
                            setState(() => _isSidebarOpen = !_isSidebarOpen),
                        onNewChat: _newChat,
                        deepThink: _deepThink,
                        isDesktop: true,
                        sidebarOpen: _isSidebarOpen,
                        onToggleDeepThink: () => setState(() {
                          _deepThinkTouched = true;
                          _deepThink = !_deepThink;
                        }),
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.blushGold.withValues(alpha: 0.06),
                      ),
                      Expanded(child: _buildChatList(centered: true)),
                      Selector<AIService, bool>(
                        selector: (_, ai) => ai.isLoading,
                        builder: (context, loading, _) {
                          if (loading || _isSending) {
                            return const SizedBox.shrink();
                          }
                          return _QuickReplyChips(
                            onSelect: _sendQuick,
                            centered: true,
                            studyActive: _studyDoc != null,
                          );
                        },
                      ),
                      _ErrorBanner(
                        lastSentMessage: _lastSentMessage,
                        onRetry: () => _send(retry: true),
                      ),
                      _ComposerInput(
                        inputKey: _inputKey,
                        controller: _input,
                        focusNode: _focusNode,
                        onSend: _send,
                        onPickImages: _pickImages,
                        attachedImages: _attachedImages,
                        onRemoveImage: _removeImage,
                        centered: true,
                        onPickStudyDoc: _pickingDoc ? null : _pickStudyDoc,
                        studyDocName: _studyDoc?.fileName,
                        studyDocSent: _studyDocSent,
                        studyDocTruncated: _studyDoc?.truncated ?? false,
                        onRemoveStudyDoc: _removeStudyDoc,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.twilight,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(
                  color: AppColors.auroraLilac,
                  alignment: Alignment(-0.7, -0.9),
                  size: 0.9,
                  opacity: 0.14,
                ),
                RadialGlow(
                  color: AppColors.deepRose,
                  alignment: Alignment(0.9, 0.9),
                  size: 0.8,
                  opacity: 0.10,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _MochiHeader(
                  onBack: () => context.pop(),
                  onSidebarToggle: () =>
                      setState(() => _isSidebarOpen = !_isSidebarOpen),
                  onNewChat: _newChat,
                  deepThink: _deepThink,
                  isDesktop: false,
                  sidebarOpen: _isSidebarOpen,
                  onToggleDeepThink: () => setState(() {
                    _deepThinkTouched = true;
                    _deepThink = !_deepThink;
                  }),
                ),
                Divider(
                  height: 1,
                  color: AppColors.blushGold.withValues(alpha: 0.06),
                ),
                Expanded(child: _buildChatList(centered: false)),
                Selector<AIService, bool>(
                  selector: (_, ai) => ai.isLoading,
                  builder: (context, loading, _) {
                    if (loading || _isSending) return const SizedBox.shrink();
                    return _QuickReplyChips(
                      onSelect: _sendQuick,
                      centered: false,
                      studyActive: _studyDoc != null,
                    );
                  },
                ),
                _ErrorBanner(
                  lastSentMessage: _lastSentMessage,
                  onRetry: () => _send(retry: true),
                ),
                _ComposerInput(
                  inputKey: _inputKey,
                  controller: _input,
                  focusNode: _focusNode,
                  onSend: _send,
                  onPickImages: _pickImages,
                  attachedImages: _attachedImages,
                  onRemoveImage: _removeImage,
                  centered: false,
                  onPickStudyDoc: _pickingDoc ? null : _pickStudyDoc,
                  studyDocName: _studyDoc?.fileName,
                  studyDocSent: _studyDocSent,
                  studyDocTruncated: _studyDoc?.truncated ?? false,
                  onRemoveStudyDoc: _removeStudyDoc,
                ),
              ],
            ),
          ),
          MochiSidebar(
            isOpen: _isSidebarOpen,
            onClose: () => setState(() => _isSidebarOpen = false),
            onNewChat: _newChat,
          ),
        ],
      ),
    );
  }

  Widget _buildChatList({required bool centered}) {
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
            final allMsgs = snapshot.$1?.messages ?? const <AIMessage>[];
            final loading = snapshot.$3;

            if (allMsgs.isEmpty && !loading) {
              return _GreetingEmptyState(onTap: _sendQuick, centered: centered);
            }

            final itemCount = allMsgs.length + (loading ? 1 : 0);

            Widget list = ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.symmetric(
                horizontal: centered ? 24 : 16,
                vertical: 14,
              ),
              itemCount: itemCount,
              itemBuilder: (_, i) {
                if (i == allMsgs.length) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: centered ? 760 : double.infinity,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ValueListenableBuilder<int>(
                          valueListenable: ai.draftRevisionNotifier,
                          builder: (context, _, _) {
                            final hasStream =
                                ai.draftResponse.isNotEmpty ||
                                ai.draftReasoning.isNotEmpty ||
                                ai.toolStatus.isNotEmpty;
                            if (hasStream) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _MessageBubble(
                                    text: ai.draftResponse,
                                    isUser: false,
                                    isStreaming: true,
                                    reasoning: ai.draftReasoning.isNotEmpty
                                        ? ai.draftReasoning
                                        : null,
                                    toolStatus: ai.toolStatus,
                                  ),
                                  ValueListenableBuilder<List<Map<String, dynamic>>>(
                                    valueListenable: ai.toolResultsNotifier,
                                    builder: (context, results, _) {
                                      if (results.isEmpty) return const SizedBox.shrink();
                                      return _ToolResultCards(results: results, centered: centered);
                                    },
                                  ),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ThinkingIndicator(
                                  toolStatus: ai.toolStatus,
                                ),
                                ValueListenableBuilder<List<Map<String, dynamic>>>(
                                  valueListenable: ai.toolResultsNotifier,
                                  builder: (context, results, _) {
                                    if (results.isEmpty) return const SizedBox.shrink();
                                    return _ToolResultCards(results: results, centered: centered);
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }
                final msg = allMsgs[i];
                final bubble = _MessageBubble(
                  key: ValueKey(
                    'msg_${msg.timestamp.millisecondsSinceEpoch}_$i',
                  ),
                  text: msg.content,
                  isUser: msg.role == 'user',
                  timestamp: msg.timestamp,
                  imageUrls: msg.imageUrls,
                );
                if (!centered) return bubble;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
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
              return ScrollConfiguration(
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
            return list;
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
}

// ─── Header ──────────────────────────────────────────────────────
