part of 'motchi_screen.dart';

// ─── Markdown renderer ───────────────────────────────────────────
// Delegates to the shared EverglowMarkdown so Motchi and Study render
// headings, lists, tables, and dividers identically (no raw `**` / `|`).

class _MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const _MarkdownText({required this.text, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    return EverglowMarkdown(
      text: text,
      plain: true,
      baseStyle:
          baseStyle ??
          AppTypography.bodyMedium().copyWith(
            fontFamily: AppTypography.reading,
            fontWeight: FontWeight.w400,
            color: AppColors.textHigh,
            height: 1.55,
          ),
    );
  }
}

String _formatToolStatus(String status) {
  if (status == 'generating') return 'Motchi is thinking... 🍡';
  if (status == 'thinking') return 'Motchi is thinking... 🍡';
  if (status == 'executing') return 'Motchi is working on it... 🐾';
  if (status == 'done') return 'Motchi is done ✨';
  if (status == 'request_tools') return 'Motchi is getting ready... 🐾';
  if (status.startsWith('round_')) return 'Motchi is thinking... 🍡';
  // Tool names — expressive cat companion activities
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

IconData _toolIcon(String status) {
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
