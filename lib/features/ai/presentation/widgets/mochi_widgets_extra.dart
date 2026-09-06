part of 'mochi_screen.dart';

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
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _BrokenImageTile(),
                  )
                : AppNetworkImage(
                    imageUrl: url,
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    cacheWidth: 400,
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
    final displayText = widget.isUser ? widget.text : stripMarkdown(bubbleText);
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: widget.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
                  maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                    topLeft: Radius.circular(widget.isUser ? AppRadius.lg : 4),
                    topRight: Radius.circular(widget.isUser ? 4 : AppRadius.lg),
                    bottomLeft: const Radius.circular(AppRadius.lg),
                    bottomRight: const Radius.circular(AppRadius.lg),
                  ),
                  border: widget.isUser
                      ? null
                      : Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: widget.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
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
                            color: AppColors.velvet.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.blushGold.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.psychology_rounded,
                                    size: 14,
                                    color: AppColors.blushGold.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Thinking${widget.isStreaming ? '...' : ''}',
                                    style: AppTypography.bodySmall().copyWith(
                                      fontSize: 10,
                                      color: AppColors.textMuted.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _showReasoning
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 14,
                                    color: AppColors.textDisabled,
                                  ),
                                ],
                              ),
                              if (_showReasoning) ...[
                                const SizedBox(height: 4),
                                EverglowMarkdown(
                                  text: widget.reasoning!,
                                  paragraphGap: 4,
                                  baseStyle: AppTypography.bodySmall().copyWith(
                                    fontSize: 10,
                                    color: AppColors.textMuted.withValues(
                                      alpha: 0.6,
                                    ),
                                    height: 1.4,
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
                          height: 1.5,
                        ),
                      )
                    else if (widget.isStreaming && bubbleText.isEmpty)
                      _StreamingPlaceholder(toolStatus: widget.toolStatus ?? '')
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MarkdownText(
                              text: bubbleText,
                              baseStyle: AppTypography.bodyMedium().copyWith(
                                color: AppColors.textHigh,
                                height: 1.55,
                              ),
                            ),
                          ),
                          if (widget.isStreaming && bubbleText.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(left: 4, top: 3),
                              child: _StreamingCaret(),
                            ),
                        ],
                      ),
                    if (widget.isStreaming)
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: _StreamingProgressBar(),
                      ),
                    // W5 citation footer — subtle source hint for assistant replies
                    if (!widget.isUser &&
                        !widget.isStreaming &&
                        widget.text.length > 60)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 10,
                              color: AppColors.textDisabled.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Mochi • private memory + Everglow context',
                              style: AppTypography.bodySmall().copyWith(
                                fontSize: 9,
                                color: AppColors.textDisabled.withValues(
                                  alpha: 0.5,
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
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
                                decoration: const BoxDecoration(
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
                                    ? AppColors.petalWhite.withValues(
                                        alpha: 0.5,
                                      )
                                    : AppColors.textMuted.withValues(
                                        alpha: 0.6,
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
// Delegates to the shared EverglowMarkdown so Mochi and Study render
// headings, lists, tables, and dividers identically (no raw `**` / `|`).

class _MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const _MarkdownText({required this.text, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    return EverglowMarkdown(
      text: text,
      baseStyle:
          baseStyle ??
          AppTypography.bodyMedium().copyWith(
            color: AppColors.textHigh,
            height: 1.55,
          ),
    );
  }
}

String _formatToolStatus(String status) {
  if (status == 'generating') return 'Mochi is thinking';
  if (status == 'thinking') return 'Mochi is thinking';
  if (status == 'executing') return 'Mochi is working on it';
  if (status == 'done') return 'Mochi is done';
  if (status.startsWith('round_')) return 'Mochi is thinking';
  // Tool names — W2-W3 additions included
  const toolNames = {
    'add_to_watchlist': 'Adding to watchlist',
    'save_to_starlight_jar': 'Saving to Starlight Jar',
    'read_starlight_jar': 'Reading the Starlight Jar',
    'set_mood': 'Logging mood',
    'search_movies': 'Searching movies',
    'get_watchlist': 'Reading the watchlist',
    'get_weather': 'Checking weather',
    'create_reminder': 'Creating reminder',
    'log_activity': 'Logging activity',
    'search_books': 'Searching books',
    'add_book_to_our_books': 'Adding book to Our Books',
    'get_date_ideas': 'Getting date ideas',
    'read_chat_messages': 'Reading chat messages',
    'send_sanctuary_message': 'Sending to Sanctuary',
    'get_xp_stats': 'Checking XP stats',
    'search_anime': 'Searching anime',
    'remember_fact': 'Remembering that',
    'read_memories': 'Opening the Memory Book',
    'pin_memory': 'Pinning memory',
    'delete_memory': 'Forgetting that',
    'edit_memory': 'Updating memory',
    'mark_watchlist_item_watched': 'Marking as watched',
    'update_book_progress': 'Updating book progress',
    'add_xp': 'Awarding XP',
    'send_note_to_partner': 'Sending a note',
    'get_relationship_insights': 'Finding patterns',
    'get_memory_trivia': 'Making memory trivia',
    'get_today_recap': 'Compiling today',
    'get_gallery': 'Browsing gallery',
    'get_garden': 'Checking garden',
    'get_canvas': 'Looking at drawings',
    'search_spotify': 'Searching Spotify',
    'remove_from_watchlist': 'Removing from watchlist',
    'search_everglow': 'Searching Everglow',
    'plan_date_night': 'Planning date night',
    'add_calendar_event': 'Creating calendar event',
    'create_journal_entry': 'Writing journal',
    'add_bucket_item': 'Adding to bucket list',
    'add_trip': 'Creating trip',
    'add_trip_pin': 'Adding trip pin',
    'log_habit': 'Creating habit',
    'complete_habit': 'Completing habit',
    'get_calendar_events': 'Reading calendar',
    'get_bucket_list': 'Reading bucket list',
    'get_journal_entries': 'Reading journal',
    'get_trips': 'Reading trips',
  };
  return toolNames[status] ?? 'Mochi is thinking';
}

IconData _toolIcon(String status) {
  switch (status) {
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
    case 'get_trips':
      return Icons.map_rounded;
    default:
      return Icons.auto_fix_high_rounded;
  }
}

Color _toolAccent(String status) {
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
    case 'get_trips':
      return AppColors.textMuted;
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

bool _isToolAction(String status) {
  return status.isNotEmpty &&
      status != 'generating' &&
      status != 'thinking' &&
      status != 'executing' &&
      status != 'done' &&
      !status.startsWith('round_');
}

/// Compact pill showing which agent action Mochi is performing.
class _ToolStatusChip extends StatelessWidget {
  final String status;

  const _ToolStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final accent = _toolAccent(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_toolIcon(status), size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            _formatToolStatus(status),
            style: AppTypography.bodySmall().copyWith(
              fontSize: 11,
              color: accent,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick-reply chips shown above the composer for one-tap follow-ups.
class _QuickReplyChips extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final bool centered;

  const _QuickReplyChips({required this.onSelect, this.centered = false});

  static const _chips = [
    ('What should we watch? 🎬', 'What should we watch tonight?'),
    ('Save to Starlight ✨', 'Save this to our Starlight Jar'),
    ('Log my mood 💭', 'I want to log my mood'),
    ('Plan a date 🌙', 'Plan a cozy date night for us'),
    ('Add calendar 📅', 'Add a calendar event for tomorrow at 7pm'),
    ('Bucket dream ✨', 'Add something to our bucket list'),
    ('Journal ✍️', 'Create a journal entry about today'),
    ('Our trips ✈️', 'Show our upcoming trips'),
  ];

  @override
  Widget build(BuildContext context) {
    final inner = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: centered ? 24 : 12,
        vertical: 6,
      ),
      child: Row(
        children: _chips.map((e) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                e.$1,
                style: AppTypography.bodySmall().copyWith(
                  fontSize: 11,
                  color: AppColors.textMedium,
                ),
              ),
              backgroundColor: AppColors.surfaceGlass,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusFull),
              onPressed: () => onSelect(e.$2),
            ),
          );
        }).toList(),
      ),
    );
    if (!centered) return inner;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: inner,
      ),
    );
  }
}

/// Inline cards for tool results — rendered below the streaming bubble
class _ToolResultCards extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final bool centered;
  const _ToolResultCards({required this.results, this.centered = false});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: results.map((r) {
          final tool = r['tool'] as String? ?? 'tool';
          final success = r['success'] == true;
          final needsConfirm = r['needs_confirmation'] == true;
          final title =
              r['title'] as String? ??
              r['fact'] as String? ??
              r['id'] as String? ??
              '';
          final msg = r['message'] as String? ?? '';
          Color accent = _toolAccent(tool);
          IconData icon = _toolIcon(tool);
          String label = _formatToolStatus(tool);
          if (needsConfirm) {
            label = 'Needs confirmation';
          } else if (success) {
            label = '$label ✓';
          } else if (r['error'] != null) {
            label = 'Failed';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.bodySmall().copyWith(
                          fontSize: 11,
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: AppTypography.bodySmall().copyWith(
                            fontSize: 11,
                            color: AppColors.textHigh,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (msg.isNotEmpty && !needsConfirm)
                        Text(
                          msg,
                          style: AppTypography.bodySmall().copyWith(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (needsConfirm && msg.isNotEmpty)
                        Text(
                          msg,
                          style: AppTypography.bodySmall().copyWith(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Animated placeholder shown while Mochi is thinking before any text or
/// tool activity has streamed in.
