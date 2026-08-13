// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// Mochi runs on Flutter web only; dart:html powers image attachments and
// browser clipboard integration that has no non-web equivalent here.
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/ai_service.dart';
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
import 'mochi_sidebar.dart';
part 'mochi_widgets.dart';
part 'mochi_widgets_streaming.dart';
part 'mochi_widgets_extra.dart';

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
  bool _userScrolledUp = false;
  // Deep thinking on by default so Mochi reasons before answering; the
  // header toggle turns it off for fast replies.
  bool _deepThink = true;
  bool _deepThinkTouched = false;
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
      ai.addListener(_onAiChanged);
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
    context.read<AIService>().removeListener(_onAiChanged);
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
    final text = retry ? (_lastSentMessage ?? '').trim() : _input.text.trim();
    final hasImages = !retry && _attachedImageUrls.isNotEmpty;
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
        enableThinking: _deepThinkTouched
            ? _deepThink
            : _deepThink || const MochiQuality().shouldAutoThink(text),
        imageUrls: imagesToSend,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mochi couldn\'t respond: $msg',
            style: AppTypography.bodySmall(),
          ),
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
          // Resize large photos to a compact JPEG so the AI proxy request
          // stays well under Cloud Run's size limit. Without this, full-size
          // phone photos (multi-MB base64) get rejected with HTTP 500.
          // Small images pass through unchanged (canvas re-encode could
          // actually grow tiny PNGs).
          final base64Data = bytes.length > 300 * 1024
              ? await _resizeImageToDataUri(bytes)
              : 'data:image/${image.name.split('.').last};base64,${base64Encode(bytes)}';
          if (!mounted) return;
          setState(() {
            _attachedImages.add(base64Data);
            // Agnes supports base64 data URIs via image_url, so we send the
            // same compact data URI to the API.
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

  /// Draws the image bytes onto a canvas, scales it down to at most
  /// [maxDim] on the long edge, and returns a compact JPEG data URI.
  Future<String> _resizeImageToDataUri(Uint8List bytes,
      {int maxDim = 1280}) async {
    final blob = html.Blob([bytes]);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    final completer = Completer<String>();
    try {
      final img = html.ImageElement();
      img.onLoad.listen((_) async {
        try {
          final scale = math.min(
            1.0,
            maxDim / math.max(img.naturalWidth, img.naturalHeight),
          );
          final w = (img.naturalWidth * scale).round().clamp(1, 4096);
          final h = (img.naturalHeight * scale).round().clamp(1, 4096);
          final canvas = html.CanvasElement(width: w, height: h);
          final ctx = canvas.context2D;
          ctx.imageSmoothingEnabled = true;
          ctx.imageSmoothingQuality = 'medium';
          ctx.drawImage(img, 0, 0);
          // JPEG keeps photos small; PNG stays lossless for screenshots.
          final isPng = bytes.length > 8 &&
              bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4E &&
              bytes[3] == 0x47;
          final mime = isPng ? 'image/png' : 'image/jpeg';
          final quality = isPng ? null : 0.82;
          final dataUri = canvas.toDataUrl(mime, quality);
          completer.complete(dataUri);
        } catch (e) {
          completer.completeError(e);
        } finally {
          html.Url.revokeObjectUrl(objectUrl);
        }
      });
      img.onError.listen((_) {
        html.Url.revokeObjectUrl(objectUrl);
        if (!completer.isCompleted) {
          completer.completeError(Exception('Image could not be loaded'));
        }
      });
      img.src = objectUrl;
      await completer.future;
    } catch (e) {
      html.Url.revokeObjectUrl(objectUrl);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
    return completer.future;
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
          // Atmosphere
          Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: const [
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
          // Main content
          SafeArea(
            child: Column(
              children: [
                _MochiHeader(
                  onBack: () => context.pop(),
                  onSidebarToggle: () =>
                      setState(() => _isSidebarOpen = !_isSidebarOpen),
                  onNewChat: _newChat,
                  deepThink: _deepThink,
                  onToggleDeepThink: () => setState(() {
                    _deepThinkTouched = true;
                    _deepThink = !_deepThink;
                  }),
                ),
                Divider(
                  height: 1,
                  color: AppColors.blushGold.withValues(alpha: 0.06),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Selector<AIService, (AIConversation?, int, bool)>(
                        selector: (_, ai) => (
                          ai.assistantConversation,
                          ai.assistantConversation?.messages.length ?? 0,
                          ai.isLoading,
                        ),
                        builder: (context, snapshot, _) {
                          final ai = context.read<AIService>();
                          final allMsgs =
                              snapshot.$1?.messages ?? const <AIMessage>[];
                          final loading = snapshot.$3;

                          if (allMsgs.isEmpty && !loading) {
                            return _GreetingEmptyState(onTap: _sendQuick);
                          }

                          // The streaming bubble is the only widget that
                          // listens to per-token revisions; history messages
                          // stay untouched while the reply streams in.
                          final itemCount =
                              allMsgs.length + (loading ? 1 : 0);

                          return ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            itemCount: itemCount,
                            itemBuilder: (_, i) {
                              if (i == allMsgs.length) {
                                return ValueListenableBuilder<int>(
                                  valueListenable: ai.draftRevisionNotifier,
                                  builder: (context, _, _) {
                                    final hasStream =
                                        ai.draftResponse.isNotEmpty ||
                                        ai.draftReasoning.isNotEmpty ||
                                        ai.toolStatus.isNotEmpty;
                                    if (hasStream) {
                                      return _MessageBubble(
                                        text: ai.draftResponse,
                                        isUser: false,
                                        isStreaming: true,
                                        reasoning:
                                            ai.draftReasoning.isNotEmpty
                                            ? ai.draftReasoning
                                            : null,
                                        toolStatus: ai.toolStatus,
                                      );
                                    }
                                    return _ThinkingIndicator(
                                      toolStatus: ai.toolStatus,
                                    );
                                  },
                                );
                              }
                              final msg = allMsgs[i];
                              return _MessageBubble(
                                key: ValueKey(
                                  'msg_${msg.timestamp.millisecondsSinceEpoch}_$i',
                                ),
                                text: msg.content,
                                isUser: msg.role == 'user',
                                timestamp: msg.timestamp,
                                imageUrls: msg.imageUrls,
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
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceGlass,
                                    borderRadius: AppRadius.radiusFull,
                                    border: Border.all(color: AppColors.border),
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

