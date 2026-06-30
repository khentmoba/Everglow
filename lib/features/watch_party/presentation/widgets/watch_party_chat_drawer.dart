import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';

import '../../data/models/watch_party_chat_message.dart';
import '../../data/services/watch_party_chat_service.dart';
import 'watch_party_chat_bubble.dart';

/// Toggleable right-side chat drawer for the Watch Party screen.
///
/// Persists messages to `watch_party_chats/{roomId}/messages/`.
/// The roomId is the deterministic sorted-joined uids of the
/// couple, so the chat history is tied to the relationship and
/// survives media switches and re-joins.
///
/// Sits as a `Stack` overlay above the watch party iframe. When
/// closed, only a small chat icon in the screen header is visible.
/// When open, the drawer takes the right 340 px on desktop, or the
/// full width on narrow screens.
class WatchPartyChatDrawer extends StatefulWidget {
  final String roomId;

  /// Initial open/closed state. The parent (WatchPartyScreen)
  /// usually keeps this closed on first paint and lets the user
  /// tap a chat icon to open it.
  final bool initiallyOpen;

  const WatchPartyChatDrawer({
    super.key,
    required this.roomId,
    this.initiallyOpen = false,
  });

  @override
  State<WatchPartyChatDrawer> createState() => _WatchPartyChatDrawerState();
}

class _WatchPartyChatDrawerState extends State<WatchPartyChatDrawer> {
  late final WatchPartyChatService _service;
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  late Stream<List<WatchPartyChatMessage>> _messagesStream;
  late final AuthService _auth;

  bool _isOpen = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.initiallyOpen;
    _service = WatchPartyChatService();
    _auth = context.read<AuthService>();
    _inputController = TextEditingController();
    _scrollController = ScrollController();
    _messagesStream = _service.getMessagesStream(widget.roomId);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final sender = _auth.currentUser ?? 'me';
    final senderUid = _auth.uid ?? 'anonymous';
    _inputController.clear();
    setState(() => _sendError = null);

    try {
      await _service.sendMessage(
        roomId: widget.roomId,
        text: text,
        sender: sender,
        senderUid: senderUid,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = 'Could not send: $e');
      // Restore the text so the user doesn't lose what they typed.
      _inputController.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnerName = _auth.partnerName;

    return Stack(
      children: [
        // Backdrop tap-to-close on narrow viewports. On desktop the
        // drawer is small enough that we don't dim the video, so we
        // skip the backdrop.
        if (_isOpen)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                if (isWide) return const SizedBox.shrink();
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleOpen,
                  child: Container(color: Colors.black.withValues(alpha: 0.45)),
                );
              },
            ),
          ),

        // Drawer panel. Anchored to the right edge. On wide screens
        // it sits next to the video without obscuring it; on narrow
        // screens it expands to nearly the full width.
        if (_isOpen)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final drawerWidth = isWide ? 340.0 : constraints.maxWidth * 0.92;
                return FadeInRight(
                  duration: const Duration(milliseconds: 220),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: drawerWidth,
                      decoration: BoxDecoration(
                        color: AppTheme.twilight.withValues(alpha: 0.92),
                        border: Border(
                          left: BorderSide(
                            color: AppTheme.roseQuartz.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 24,
                            offset: const Offset(-4, 0),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            _buildHeader(partnerName),
                            Expanded(child: _buildMessageList()),
                            _buildInput(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Toggle button. Always rendered so the user can re-open
        // after closing. Positioned at the right edge, mid-height.
        if (!_isOpen)
          Positioned(
            top: 80,
            right: 12,
            child: FadeInRight(
              duration: const Duration(milliseconds: 220),
              child: _buildToggleButton(),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(String partnerName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.roseQuartz.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              color: AppTheme.roseQuartz, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat with $partnerName',
                  style: GoogleFonts.cormorantGaramond(
                    color: AppTheme.roseQuartz,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Saved in this room',
                  style: GoogleFonts.outfit(
                    color: AppTheme.roseQuartz.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: AppTheme.roseQuartz.withValues(alpha: 0.7)),
            onPressed: _toggleOpen,
            tooltip: 'Close chat',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<WatchPartyChatMessage>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.roseQuartz,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Chat is unavailable. Check your connection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        final messages = snapshot.data ?? const <WatchPartyChatMessage>[];

        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_outline_rounded,
                    color: AppTheme.roseQuartz.withValues(alpha: 0.3),
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chat is empty',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      color: AppTheme.roseQuartz,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Say hi to keep the vibes going',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppTheme.roseQuartz.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Auto-scroll to the newest message only if the user is
        // already near the bottom (within 50px). This lets the user
        // scroll up to read history without being yanked back down.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final maxScroll = _scrollController.position.maxScrollExtent;
            final currentScroll = _scrollController.position.pixels;
            if ((maxScroll - currentScroll).abs() < 50.0) {
              _scrollToBottom();
            }
          }
        });

        final currentUid = _auth.uid;
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final m = messages[index];
            final isMe = m.senderUid.isNotEmpty && m.senderUid == currentUid;
            return WatchPartyChatBubble(
              key: ValueKey(m.id),
              text: m.text,
              isMe: isMe,
              sender: m.sender.isEmpty ? 'Anon' : m.sender,
              timestamp: m.timestamp,
            );
          },
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.roseQuartz.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
              child: Text(
                _sendError!,
                style: GoogleFonts.outfit(
                  color: Colors.redAccent,
                  fontSize: 10,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _inputController,
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite,
                      fontSize: 13,
                    ),
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: GoogleFonts.outfit(
                        color: AppTheme.petalWhite.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppTheme.deepRose,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: AppTheme.petalWhite,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: _toggleOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.roseQuartz.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_rounded,
                color: AppTheme.roseQuartz, size: 14),
            const SizedBox(width: 6),
            Text(
              'Chat',
              style: GoogleFonts.outfit(
                color: AppTheme.roseQuartz,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
