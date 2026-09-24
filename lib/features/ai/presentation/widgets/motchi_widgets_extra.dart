part of 'motchi_screen.dart';

class _MessageImages extends StatelessWidget {
  final List<String> imageUrls;

  const _MessageImages({required this.imageUrls});

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
                    errorBuilder: (_, _, _) => _BrokenImageTile(),
                  )
                : AppNetworkImage(
                    imageUrl: url,
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    cacheWidth: 540,
                    errorWidget: _BrokenImageTile(),
                  ),
          ),
        );
      }).toList(),
    );
  }
}

class _BrokenImageTile extends StatelessWidget {
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

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showReasoning = true;

  @override
  void didUpdateWidget(covariant _MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new stream is starting: show thinking notes again.
    if (oldWidget.isStreaming &&
        oldWidget.text.isNotEmpty &&
        widget.isStreaming &&
        widget.text.isEmpty) {
      _showReasoning = true;
      return;
    }
    // Once the visible answer starts arriving, collapse the thinking notes
    // so the reply stays front and center.
    if (oldWidget.text.isEmpty &&
        widget.text.isNotEmpty &&
        widget.isStreaming) {
      _showReasoning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The model often starts replies with blank lines; trim them for a
    // clean first line in the bubble (both while streaming and after).
    final bubbleText = widget.isUser ? widget.text : widget.text.trimLeft();
    // Canvas / Artifacts: when Motchi answers a quiz / flashcards ask, the
    // reply carries hidden quiz-json / flashcards-json blocks. Strip them
    // so Clair never sees raw JSON — she sees warm text + one big tappable
    // button (StudyArtifactEntry) that opens the interactive sheet
    // (Q1 → answer → Next → Q2 … with score, flippable cards).
    // The visible question list collapses too, unless she explicitly asked
    // to see it inline (keepFullText) — an explicit ask always wins.
    // Mid-stream, cut an unterminated fence too so half-JSON never flashes.
    final cleanBubbleText = widget.isUser
        ? bubbleText
        : widget.isStreaming
            ? stripStreamingArtifacts(bubbleText)
            : stripArtifactBlocks(
                bubbleText,
                collapseVisibleLists: !widget.keepFullText,
              );
    final artifacts = widget.isUser
        ? const StudyArtifacts()
        : parseStudyArtifacts(bubbleText);
    final displayText = widget.isUser ? widget.text : stripMarkdown(cleanBubbleText);
    final hasReasoning =
        widget.reasoning != null && widget.reasoning!.isNotEmpty;

    final timeStr = widget.timestamp != null
        ? DateFormat('h:mm a').format(widget.timestamp!)
        : '';
    final isToday =
        widget.timestamp != null &&
        DateTime.now().day == widget.timestamp!.day &&
        DateTime.now().month == widget.timestamp!.month &&
        DateTime.now().year == widget.timestamp!.year;
    final fullDateStr = widget.timestamp != null
        ? DateFormat('MMM d, h:mm a').format(widget.timestamp!)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: widget.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isUser) ...[
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blushGold.withValues(alpha: 0.30),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: AppColors.auroraLilac.withValues(alpha: 0.18),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/motchi_avatar.webp',
                      width: 38,
                      height: 38,
                      cacheWidth: kIsWeb ? null : 114,
                      cacheHeight: kIsWeb ? null : 114,
                      filterQuality: FilterQuality.high,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: AppColors.inkDeep,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.blushGold.withValues(alpha: 0.70),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.pets_rounded,
                      size: 9,
                      color: AppColors.blushGold,
                    ),
                  ),
                ),
              ],
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
                    content: Text('Copied', style: AppTypography.bodySmall()),
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppColors.velvet,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusLg,
                    ),
                    margin: const EdgeInsets.all(AppSpacing.lg),
                  ),
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width *
                      (widget.isUser ? 0.78 : 0.82),
                ),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                decoration: BoxDecoration(
                  gradient: widget.isUser
                      ? const LinearGradient(
                          colors: [
                            AppColors.deepRose,
                            AppColors.roseDepths,
                            AppColors.plum,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            AppColors.inkDeep.withValues(alpha: 0.94),
                            AppColors.velvet.withValues(alpha: 0.72),
                            AppColors.inkDeep.withValues(alpha: 0.90),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: widget.isUser
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(8),
                          bottomLeft: Radius.circular(22),
                          bottomRight: Radius.circular(22),
                        )
                      : const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(24),
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                  border: Border.all(
                    color: widget.isUser
                        ? AppColors.petalWhite.withValues(alpha: 0.24)
                        : AppColors.blushGold.withValues(alpha: 0.18),
                    width: 1.0,
                  ),
                  boxShadow: widget.isUser
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: AppColors.deepRose.withValues(alpha: 0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.38),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: AppColors.blushGold.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: widget.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!widget.isUser) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.blushGold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.blushGold.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.pets_rounded,
                                  size: 10,
                                  color: AppColors.blushGold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'MOTCHI',
                                  style: AppTypography.labelSmall().copyWith(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.blushGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isStreaming) ...[
                            const SizedBox(width: 8),
                            Text(
                              'purring…',
                              style: AppTypography.bodySmall().copyWith(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppColors.blushGold.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (hasReasoning)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showReasoning = !_showReasoning),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.inkDeep.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.blushGold.withValues(
                                alpha: 0.28,
                              ),
                              width: 0.9,
                            ),
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
                                    color: AppColors.blushGold.withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                              if (_showReasoning) ...[
                                const SizedBox(height: 4),
                                EverglowMarkdown(
                                  text: widget.reasoning!,
                                  paragraphGap: 4,
                                  baseStyle: AppTypography.bodySmall().copyWith(
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
                      _MessageImages(imageUrls: widget.imageUrls),
                      if (widget.text.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (widget.isUser)
                      Text(
                        widget.text,
                        style: AppTypography.bodyMedium().copyWith(
                          color: AppColors.petalWhite,
                          height: 1.55,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else if (widget.isStreaming && cleanBubbleText.isEmpty)
                      const _StreamingPlaceholder()
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Interactive canvas entry — one big obvious button
                          // when the reply carries a quiz / flashcards.
                          // Shown only once streaming finishes so the button
                          // never flickers mid-stream.
                          if (!widget.isUser &&
                              !widget.isStreaming &&
                              widget.showArtifacts &&
                              !artifacts.isEmpty)
                            StudyArtifactEntry(artifacts: artifacts),
                          Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MarkdownText(
                              text: cleanBubbleText,
                              baseStyle: AppTypography.bodyMedium().copyWith(
                                color: AppColors.textHigh,
                                height: 1.55,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.isStreaming && cleanBubbleText.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(left: 4, top: 3),
                              child: _StreamingCaret(),
                            ),
                        ],
                          ),
                        ],
                      ),
                    if (widget.isStreaming)
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: _StreamingProgressBar(),
                      ),
                    // Cozy footer: whispered for you two with soft icon actions
                    if (!widget.isUser && !widget.isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 11,
                              color: AppColors.blushGold.withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                widget.timestamp == null
                                    ? 'Whispered for you two 🐾'
                                    : '${isToday ? timeStr : fullDateStr} · Whispered for you two 🐾',
                                style: AppTypography.bodySmall().copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            if (displayText.trim().isNotEmpty) ...[
                              EverglowCopyIconButton(textToCopy: displayText),
                              const SizedBox(width: 4),
                              _ListenButton(text: displayText),
                            ],
                          ],
                        ),
                      ),
                    if (widget.timestamp != null && widget.isUser)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 10,
                              color: AppColors.blushGold.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isToday ? timeStr : fullDateStr,
                              style: AppTypography.bodySmall().copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.petalWhite.withValues(
                                  alpha: 0.85,
                                ),
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
            _UserAvatar(name: widget.senderName),
          ],
        ],
      ),
    );
  }
}

class _ListenButton extends StatefulWidget {
  final String text;
  const _ListenButton({required this.text});

  @override
  State<_ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends State<_ListenButton> {
  bool _speaking = false;

  void _toggle() {
    HapticFeedback.lightImpact();
    if (_speaking) {
      WebTtsService.instance.stop();
      if (mounted) setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      WebTtsService.instance.speak(
        widget.text,
        onComplete: () {
          if (mounted) setState(() => _speaking = false);
        },
      );
    }
  }

  @override
  void dispose() {
    if (_speaking) {
      WebTtsService.instance.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!WebTtsService.instance.isSupported) return const SizedBox.shrink();
    return Tooltip(
      message: _speaking ? 'Stop speaking' : 'Listen to Motchi',
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                size: 13,
                color: _speaking ? AppColors.auroraRose : AppColors.blushGold,
              ),
              const SizedBox(width: 3.5),
              Text(
                _speaking ? 'Stop' : 'Listen',
                style: AppTypography.labelSmall().copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _speaking ? AppColors.auroraRose : AppColors.blushGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initial-letter avatar for the user's own messages, so they are visually
/// distinct from Motchi's cat avatar.
class _UserAvatar extends StatelessWidget {
  final String? name;

  const _UserAvatar({this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = (name ?? '').trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final isClair = trimmed.toLowerCase().startsWith('c');
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isClair
              ? const [AppColors.auroraRose, AppColors.deepRose]
              : const [AppColors.deepRose, AppColors.plum],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.blushGold.withValues(alpha: 0.60),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: (isClair ? AppColors.auroraRose : AppColors.deepRose)
                .withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTypography.bodySmall().copyWith(
            fontSize: 13,
            color: AppColors.petalWhite,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
