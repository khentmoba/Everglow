import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_colors.dart';
import 'package:everglow/services/auth_service.dart';

import '../../data/models/temporary_chat_message.dart';
import '../../data/services/temporary_chat_service.dart';

/// Realtime temporary chat panel for the Watch Together tab.
///
/// This is the couple-only ephemeral thread: messages stream live from
/// Firestore, are scoped to the couple's deterministic room id, and can
/// be cleared at any time. It intentionally does not reuse the active
/// party room chat, so conversation can happen before a movie night
/// starts and without polluting permanent party history.
class TemporaryChatPanel extends StatefulWidget {
  final String roomId;
  final String myUid;
  final String partnerUid;

  const TemporaryChatPanel({
    super.key,
    required this.roomId,
    required this.myUid,
    required this.partnerUid,
  });

  @override
  State<TemporaryChatPanel> createState() => _TemporaryChatPanelState();
}

class _TemporaryChatPanelState extends State<TemporaryChatPanel> {
  final TemporaryChatService _service = TemporaryChatService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Stream<List<TemporaryChatMessage>>? _stream;
  bool _sending = false;
  bool _clearing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _ensureRoom();
    if (!mounted) return;
    setState(() {
      _stream = _service.getMessagesStream(widget.roomId);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ensureRoom() async {
    await _service.ensureRoom(
      roomId: widget.roomId,
      myUid: widget.myUid,
      partnerUid: widget.partnerUid,
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final auth = context.read<AuthService>();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.sendMessage(
        roomId: widget.roomId,
        text: text,
        sender: auth.currentUser ?? 'Me',
        senderUid: auth.uid ?? widget.myUid,
      );
      _input.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not send the message.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _clear() async {
    if (_clearing) return;
    setState(() {
      _clearing = true;
      _error = null;
    });
    try {
      await _service.clearMessages(widget.roomId);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not clear the chat.');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final partnerName = auth.partnerName;
    return Container(
      decoration: BoxDecoration(
        color: NetflixColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NetflixColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(partnerName),
          SizedBox(
            height: 240,
            child: StreamBuilder<List<TemporaryChatMessage>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildMessage(
                    'Chat is unavailable. Check your connection.',
                    icon: Icons.cloud_off_rounded,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NetflixColors.accent,
                    ),
                  );
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return _buildMessage(
                    'Say hi to $partnerName while you pick a movie.',
                    icon: Icons.favorite_outline_rounded,
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderUid == widget.myUid;
                    return _buildBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildInput(partnerName),
        ],
      ),
    );
  }

  Widget _buildHeader(String partnerName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: NetflixColors.hairline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: NetflixColors.accent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temporary Chat',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 14,
                    color: NetflixColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Live with $partnerName · clears anytime',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 10.5,
                    color: NetflixColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearing ? null : _clear,
            icon: _clearing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NetflixColors.accent,
                    ),
                  )
                : const Icon(
                    Icons.delete_sweep_outlined,
                    color: NetflixColors.textSecondary,
                    size: 18,
                  ),
            tooltip: 'Clear chat',
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(TemporaryChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isMe
              ? NetflixColors.accent.withValues(alpha: 0.22)
              : NetflixColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe
                ? NetflixColors.accent.withValues(alpha: 0.45)
                : NetflixColors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMe ? 'You' : message.sender,
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 10,
                color: isMe
                    ? NetflixColors.accent
                    : NetflixColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              message.text,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 12.5,
                color: NetflixColors.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String text, {required IconData icon}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: NetflixColors.textMuted, size: 28),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 12,
                color: NetflixColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String partnerName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: NetflixColors.hairline, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _error!,
                style: AppTypography.outfitWhite.copyWith(
                  color: NetflixColors.accent,
                  fontSize: 10.5,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: TextField(
                    controller: _input,
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 13,
                      color: NetflixColors.textPrimary,
                    ),
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Message $partnerName...',
                      hintStyle: AppTypography.outfitWhite.copyWith(
                        color: NetflixColors.textMuted,
                        fontSize: 12,
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
                onTap: _sending ? null : _send,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: NetflixColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
