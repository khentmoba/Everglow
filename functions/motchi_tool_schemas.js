'use strict';

/* Motchi tool schemas + per-request selection — moved verbatim
 * from motchi_chat.js handleProxyAI() (mechanical split).
 * MOTCHI_TOOLS is the full function-calling schema array;
 * selectToolsForRequest prunes it per feature/greeting/intent.
 */

const { CORE_TOOLS, selectToolNames } = require('./motchi_tools.js');

const MOTCHI_TOOLS = [
  {
    type: 'function',
    function: {
      name: 'add_to_watchlist',
      description: 'Add a movie or TV show to Khent & Clair\'s shared cinema watchlist. Use when they want to watch something or ask to add a movie/show. If search_movies returned multiple close matches, use tmdb_id from the chosen candidate.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'The movie or TV show title to search for (ignored if tmdb_id is provided)' },
          media_type: { type: 'string', enum: ['movie', 'tv'], description: 'Whether it is a movie or TV show' },
          tmdb_id: { type: 'number', description: 'TMDB ID from a prior search_movies result — use when disambiguating between candidates' },
        },
        required: ['title'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'save_to_starlight_jar',
      description: 'Save a gratitude note, memory, or heartfelt message to the Starlight Jar. Use when the user asks to save something meaningful.',
      parameters: {
        type: 'object',
        properties: {
          note: { type: 'string', description: 'The gratitude note or message content' },
        },
        required: ['note'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'set_mood',
      description: 'Log the user\'s current mood/feeling. Use when they express how they feel.',
      parameters: {
        type: 'object',
        properties: {
          mood: { type: 'string', description: 'The mood keyword (e.g., happy, sad, tired, excited, stressed)' },
          note: { type: 'string', description: 'Optional short note about why they feel this way' },
        },
        required: ['mood'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_movies',
      description: 'Search TMDB for movies or TV shows. Use for recommendations, finding specific titles, or when asked about what to watch.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Search query (title, genre, or description)' },
          media_type: { type: 'string', enum: ['movie', 'tv', 'multi'], description: 'Filter by type (default: multi)' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_weather',
      description: 'Get current weather for a location. Use for date planning or when asked about weather.',
      parameters: {
        type: 'object',
        properties: {
          location: { type: 'string', description: 'City name (e.g., "Cabadbaran", "Manila")' },
        },
        required: ['location'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_reminder',
      description: 'Create a reminder for Khent or Clair. Use when they ask to be reminded about something.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Short reminder title' },
          remind_at: { type: 'string', description: 'ISO 8601 datetime or relative description (e.g., "tomorrow at 3pm")' },
          note: { type: 'string', description: 'Additional details for the reminder' },
        },
        required: ['title', 'remind_at'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_reminders',
      description: 'List pending (not yet fired) reminders for Khent and Clair. Use when they ask what reminders exist.',
      parameters: {
        type: 'object',
        properties: {},
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'cancel_reminder',
      description: 'Cancel a pending reminder by id or title. Title matches ask for confirmation first (re-call with confirm:true).',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Reminder id from list_reminders' },
          title: { type: 'string', description: 'Reminder title to match (asks confirmation unless confirm is true)' },
          confirm: { type: 'boolean', description: 'Set true to confirm cancelling title matches' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'log_activity',
      description: 'Log a notable activity or event to recent activity feed. Use to track what Khent & Clair have been doing.',
      parameters: {
        type: 'object',
        properties: {
          activity: { type: 'string', description: 'Description of the activity' },
          category: { type: 'string', enum: ['date', 'gaming', 'movie', 'music', 'food', 'travel', 'other'], description: 'Activity category' },
        },
        required: ['activity'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_books',
      description: 'Search Open Library for books by title, author, or ISBN. Use when they ask about books, want recommendations, or mention a book title.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Search query (title, author name, or ISBN)' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_date_ideas',
      description: 'Get random date ideas from a curated list of 1000+ ideas. Use when they ask for date suggestions or what to do together.',
      parameters: {
        type: 'object',
        properties: {
          count: { type: 'number', description: 'Number of date ideas to return (default 3, max 10)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_chat_messages',
      description: 'Read recent Sanctuary (private couple chat) messages. Use when they ask about what they or their partner said recently, or to reference recent conversations.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'number', description: 'Number of recent messages to read (default 20, max 50)' },
          sender: { type: 'string', enum: ['khentsgdz', 'clairjassen', 'both'], description: 'Filter by sender (default: both)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'send_sanctuary_message',
      description: 'Send a message to the private Sanctuary couple chat as Motchi on behalf of the current user. Use when they ask you to tell their partner something or relay a message in the chat.',
      parameters: {
        type: 'object',
        properties: {
          text: { type: 'string', description: 'The message text to send (1-2000 chars)' },
        },
        required: ['text'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_xp_stats',
      description: 'Get XP and leveling information for a user. Use when they ask about their level, progress, or XP.',
      parameters: {
        type: 'object',
        properties: {
          user: { type: 'string', enum: ['khentsgdz', 'clairjassen', 'both'], description: 'Which user to get stats for (default: both)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_anime',
      description: 'Search for anime titles using the Jikan (MyAnimeList) API. Use when they ask about anime, want recommendations, or mention an anime title.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Anime search query (title, genre, or description)' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_book_to_our_books',
      description: 'Search Open Library for a book and add it to Khent & Clair\'s shared "Our Books" list. Use when they want to add a book to their shared reading list. If search_books returned multiple candidates, you may pass open_library_key to pick the exact one.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Book search query (title, author name, or ISBN)' },
          open_library_key: { type: 'string', description: 'Open Library key from a prior search_books result (e.g., "/works/OL123W") — use when disambiguating' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_starlight_jar',
      description: 'Read the most recent notes saved in the Starlight Jar. Use when they ask what is in the jar or want to revisit saved notes and memories.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'number', description: 'Number of recent notes to read (default 10, max 25)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_watchlist',
      description: 'Read Khent & Clair\'s current shared cinema watchlist. Use when they ask what is on their list or what they have been planning to watch.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'number', description: 'Number of items per person to read (default 15, max 40)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'remember_fact',
      description: 'Save a personal fact about Khent or Clair to Motchi\'s long-term memory. Use when they explicitly tell you something to remember about themselves, each other, or their relationship.',
      parameters: {
        type: 'object',
        properties: {
          fact: { type: 'string', description: 'The fact to remember, phrased naturally (e.g., "Khent prefers black coffee")' },
          category: { type: 'string', enum: ['fact', 'preference', 'dislike', 'goal', 'date', 'habit'], description: 'Category of the fact (default: fact)' },
        },
        required: ['fact'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_memories',
      description: 'Browse or search Motchi\'s long-term memory book. Use when they want to see what you remember, search a memory, or review facts.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Optional search text' },
          category: { type: 'string', description: 'Optional category filter (fact, preference, dislike, goal, date, habit)' },
          limit: { type: 'number', description: 'Max memories to return (default 20, max 50)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'pin_memory',
      description: 'Pin or unpin a memory so it is always remembered. Use when they say a fact is important or to highlight a favorite memory.',
      parameters: {
        type: 'object',
        properties: {
          memory_id: { type: 'string', description: 'Memory document ID from read_memories' },
          pinned: { type: 'boolean', description: 'true to pin, false to unpin' },
        },
        required: ['memory_id', 'pinned'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'delete_memory',
      description: 'Delete a memory from Motchi\'s long-term memory. Use when they ask to forget something or remove an incorrect fact. Requires confirm=true after showing the user what will be deleted.',
      parameters: {
        type: 'object',
        properties: {
          memory_id: { type: 'string', description: 'Memory document ID from read_memories' },
          confirm: { type: 'boolean', description: 'Set true to confirm deletion after user approval' },
        },
        required: ['memory_id'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'edit_memory',
      description: 'Edit the text of an existing memory. Use when they want to correct or update a remembered fact.',
      parameters: {
        type: 'object',
        properties: {
          memory_id: { type: 'string', description: 'Memory document ID from read_memories' },
          fact: { type: 'string', description: 'The corrected fact text' },
          category: { type: 'string', enum: ['fact', 'preference', 'dislike', 'goal', 'date', 'habit'], description: 'Optional new category' },
        },
        required: ['memory_id', 'fact'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'web_search',
      description: 'Search the web for current information, news, prices, facts, or anything not covered by other tools. Use when they ask about recent events, current info, or topics outside Everglow\'s own data. Returns ranked results with titles, snippets, and URLs.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Search query (keywords or natural language)' },
          domain_type: { type: 'string', enum: ['web', 'news', 'research_paper'], description: 'Search type (default: web). Use "news" for recent articles with dates.' },
          recency_minutes: { type: 'number', description: 'Only return results newer than this many minutes (e.g. 1440 for last 24h). Cannot combine with after_date/before_date.' },
          after_date: { type: 'string', description: 'Only return results after this date (YYYY-MM-DD).' },
          before_date: { type: 'string', description: 'Only return results before this date (YYYY-MM-DD).' },
          location: { type: 'string', description: 'Country code for geo-relevant results (e.g. "PH", "US"). Default: PH.' },
          include_domains: { type: 'string', description: 'Comma-separated domains to restrict results to (e.g. "github.com,arxiv.org").' },
          exclude_domains: { type: 'string', description: 'Comma-separated domains to exclude (e.g. "pinterest.com,quora.com").' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_web_page',
      description: 'Fetch and read the full content of one or more web pages (up to 3). Use after web_search when a snippet is not enough to answer well.',
      parameters: {
        type: 'object',
        properties: {
          urls: {
            type: 'array',
            items: { type: 'string' },
            description: 'URLs to fetch (1-3)',
          },
        },
        required: ['urls'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'mark_watchlist_item_watched',
      description: 'Mark a movie or show on the shared cinema watchlist as watched. Use when they finish something or ask to update their list.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Movie or show title to mark as watched' },
        },
        required: ['title'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_book_progress',
      description: 'Update progress (0-100) for a book in the shared "Our Books" list. Progress 100 also marks it read for the caller.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Book title to update' },
          progress: { type: 'number', description: 'Progress percentage 0-100' },
        },
        required: ['title', 'progress'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_xp',
      description: 'Award XP to the caller for a completed activity or achievement inside Everglow. Be generous — every 200 XP is a level up, so meaningful moments deserve 20-50 XP and small wins 10-20.',
      parameters: {
        type: 'object',
        properties: {
          amount: { type: 'number', description: 'XP amount (1-100, default 25)' },
          reason: { type: 'string', description: 'Short reason for the XP' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'send_note_to_partner',
      description: 'Send a private note from one partner to the other through Motchi. Use when they ask you to pass a message, note, or reminder to their partner.',
      parameters: {
        type: 'object',
        properties: {
          note: { type: 'string', description: 'The note content' },
        },
        required: ['note'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_relationship_insights',
      description: 'Find gentle patterns in their moods and activities, like shared rhythms or recurring date-night habits.',
      parameters: {
        type: 'object',
        properties: {},
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_memory_trivia',
      description: 'Generate a mini memory-trivia game from real facts Motchi remembers about Khent and Clair.',
      parameters: {
        type: 'object',
        properties: {
          count: { type: 'number', description: 'Number of questions (default 5, max 10)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_today_recap',
      description: 'Compile a short, warm recap of today in Everglow: moods, activities, watchlist, starlight notes, and on-this-day memories.',
      parameters: {
        type: 'object',
        properties: {},
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_gallery',
      description: 'Read recent photos from the Gallery. Use when they ask about their photos or memories.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'number', description: 'Number of photos to fetch (default 10, max 20)' },
          include_images: { type: 'boolean', description: 'Set true ONLY when they ask about photo CONTENTS (what is in a picture, find photos showing X). Attaches up to 3 thumbnails for you to actually see — costs extra, so use sparingly.' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_garden',
      description: 'Read the garden plants and their growth. Use when they ask about their garden or plants.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'number', description: 'Number of plants to fetch (default 10, max 20)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_canvas',
      description: 'Read recent canvas drawings. Use when they ask about drawings or art.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'number', description: 'Number of drawings to fetch (default 10, max 20)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_spotify',
      description: 'Search Spotify for tracks by artist and title. Use when they ask about music or want to find a song.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Search query (e.g., "Ethel Cain Crush" or "artist - track")' },
          artist: { type: 'string', description: 'Artist name (optional if query contains artist)' },
          track: { type: 'string', description: 'Track name (optional if query contains track)' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'remove_from_watchlist',
      description: 'Remove a movie or show from the shared watchlist. Use when they ask to remove or delete something from the list. Requires confirm=true after showing what will be removed.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Title substring to match' },
          tmdb_id: { type: 'number', description: 'Exact TMDB ID to remove (optional)' },
          confirm: { type: 'boolean', description: 'Set true to confirm removal after user approval' },
        },
        required: ['title'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_everglow',
      description: 'Unified search across Everglow — movies (TMDB), books (Open Library), anime (Jikan), and music (Spotify) in one call. Use when they ask for broad recommendations or to find something without knowing the domain.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Search query for all domains' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'plan_date_night',
      description: 'Plan a complete date night by combining date ideas, weather for a location, and watchlist suggestions. Use when they ask to plan a date or a night together.',
      parameters: {
        type: 'object',
        properties: {
          location: { type: 'string', description: 'City for weather (default Cabadbaran)' },
          count: { type: 'number', description: 'Number of date ideas (default 3, max 5)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_calendar_event',
      description: 'Create a calendar event for Khent & Clair. Use when they want to schedule something, add a date night, anniversary, reminder, or any event to the shared calendar.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Event title' },
          description: { type: 'string', description: 'Optional description' },
          date: { type: 'string', description: 'ISO 8601 date/time (e.g., 2026-09-10T19:00:00) or YYYY-MM-DD' },
          end_date: { type: 'string', description: 'Optional end date/time ISO 8601' },
          type: { type: 'string', enum: ['dateNight','anniversary','reminder','custom'], description: 'Event type (default custom)' },
          location: { type: 'string', description: 'Optional location' },
          is_all_day: { type: 'boolean', description: 'Whether all-day event' },
        },
        required: ['title','date'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_journal_entry',
      description: 'Create a journal entry for Khent or Clair. Use when they want to write, reflect, save a memory, or log something personal.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Entry title' },
          content: { type: 'string', description: 'Entry content (markdown supported, 1-5000 chars)' },
          category: { type: 'string', enum: ['daily','gratitude','memory','letter','dream','idea'], description: 'Category (default daily)' },
          mood: { type: 'string', enum: ['happy','calm','loved','excited','tired','sad','stressed','neutral'], description: 'Optional mood' },
          tags: { type: 'array', items: { type: 'string' }, description: 'Optional tags' },
        },
        required: ['title','content'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_bucket_item',
      description: 'Add an item to the shared bucket list. Use when they mention a dream, goal, wish, or something they want to do together.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Bucket item title' },
          description: { type: 'string', description: 'Optional details' },
          category: { type: 'string', enum: ['travel','experience','food','adventure','milestone','other'], description: 'Category (default other)' },
          priority: { type: 'string', enum: ['low','medium','high','urgent'], description: 'Priority (default medium)' },
          due_date: { type: 'string', description: 'Optional due date ISO 8601' },
        },
        required: ['title'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_trip',
      description: 'Create a new trip in the travel planner. Use when they want to plan a trip or getaway.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Trip title (e.g., Batanes Getaway)' },
          description: { type: 'string', description: 'Optional description' },
          start_date: { type: 'string', description: 'Start date ISO 8601 YYYY-MM-DD' },
          end_date: { type: 'string', description: 'End date ISO 8601 YYYY-MM-DD' },
          budget: { type: 'number', description: 'Optional budget estimate' },
        },
        required: ['title','start_date','end_date'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_trip_pin',
      description: 'Add a pin/stop to an existing trip. Use when they want to add a place to visit on a trip.',
      parameters: {
        type: 'object',
        properties: {
          trip_id: { type: 'string', description: 'Trip document ID (from add_trip or existing trips)' },
          trip_title: { type: 'string', description: 'Alternative: trip title to match (if id unknown)' },
          title: { type: 'string', description: 'Pin title (place name)' },
          note: { type: 'string', description: 'Optional note' },
          lat: { type: 'number', description: 'Latitude' },
          lng: { type: 'number', description: 'Longitude' },
          category: { type: 'string', enum: ['stay','eat','sight','activity','transit'], description: 'Pin category (default sight)' },
        },
        required: ['title'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'log_habit',
      description: 'Create or log a wellness habit. Use when they want to track a habit, workout, or streak.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Habit title' },
          description: { type: 'string', description: 'Optional description' },
          category: { type: 'string', enum: ['health','fitness','mindfulness','learning','social','other'], description: 'Category (default health)' },
          frequency: { type: 'string', enum: ['daily','weekly','custom'], description: 'Frequency (default daily)' },
        },
        required: ['title'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'complete_habit',
      description: 'Mark a habit as completed for today (increments streak). Use when they say they did a habit or workout.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Habit title to match' },
          habit_id: { type: 'string', description: 'Optional habit document ID' },
        },
        required: ['title'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_calendar_events',
      description: 'Read upcoming calendar events. Use when they ask what is scheduled, upcoming dates, or what is on the calendar.',
      parameters: {
        type: 'object',
        properties: {
          days: { type: 'number', description: 'Days ahead to fetch (default 14, max 60)' },
          limit: { type: 'number', description: 'Max events (default 10, max 20)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_calendar_event',
      description: 'Update a calendar event by id or title. Only the provided fields change.',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Event id from get_calendar_events' },
          title: { type: 'string', description: 'Event title to match (when id is not known)' },
          new_title: { type: 'string', description: 'New title' },
          description: { type: 'string', description: 'New description' },
          date: { type: 'string', description: 'New date (ISO 8601)' },
          end_date: { type: 'string', description: 'New end date (ISO 8601)' },
          location: { type: 'string', description: 'New location' },
          type: { type: 'string', enum: ['dateNight','anniversary','reminder','custom'], description: 'New event type' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'delete_calendar_event',
      description: 'Delete a calendar event by id or title. Asks for confirmation first (re-call with confirm:true).',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Event id from get_calendar_events' },
          title: { type: 'string', description: 'Event title to match (when id is not known)' },
          confirm: { type: 'boolean', description: 'Set true to confirm deletion' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_bucket_list',
      description: 'Read the bucket list. Use when they ask about dreams, wishes, or what they want to do together.',
      parameters: {
        type: 'object',
        properties: {
          status: { type: 'string', enum: ['wish','planned','completed','all'], description: 'Filter by status (default all)' },
          limit: { type: 'number', description: 'Max items (default 10, max 20)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'complete_bucket_item',
      description: 'Mark a bucket list item completed by id or title.',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Item id from get_bucket_list' },
          title: { type: 'string', description: 'Item title to match (when id is not known)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'delete_bucket_item',
      description: 'Delete a bucket list item by id or title. Asks for confirmation first (re-call with confirm:true).',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Item id from get_bucket_list' },
          title: { type: 'string', description: 'Item title to match (when id is not known)' },
          confirm: { type: 'boolean', description: 'Set true to confirm deletion' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_journal_entries',
      description: 'Read recent journal entries. Use when they want to revisit memories or see what was written.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'number', description: 'Max entries (default 5, max 10)' },
          category: { type: 'string', enum: ['daily','gratitude','memory','letter','dream','idea','all'], description: 'Filter category (default all)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_journal_entries',
      description: 'Search journal entries across all time by keyword, topic, category, author, or tag. Use when they ask about specific past memories, topics, dates, or reflections.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Keyword or phrase to search for in entry title, content, or tags' },
          category: { type: 'string', enum: ['daily','gratitude','memory','letter','dream','idea','all'], description: 'Filter by category (default all)' },
          author: { type: 'string', description: 'Filter by author (e.g. khentsgdz or clairjassen)' },
          tag: { type: 'string', description: 'Filter by specific tag' },
          limit: { type: 'number', description: 'Max matching entries to return (default 5, max 20)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_journal_entry',
      description: 'Read the complete, full unabridged text and all details of a specific journal entry. Always use this whenever you need to read every single word, letter, or quote from an entry found via search_journal_entries or get_journal_entries.',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'The Firestore document ID of the journal entry (from search_journal_entries or get_journal_entries)' },
          title: { type: 'string', description: 'The title of the journal entry (fallback if id is not known)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'edit_journal_entry',
      description: 'Edit a journal entry by id or title. Only the provided fields change.',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Entry id from get_journal_entries or search_journal_entries' },
          title: { type: 'string', description: 'Entry title to match (when id is not known)' },
          new_title: { type: 'string', description: 'New title' },
          content: { type: 'string', description: 'New content (replaces the old text)' },
          category: { type: 'string', enum: ['daily','gratitude','memory','letter','dream','idea'], description: 'New category' },
          tags: { type: 'array', items: { type: 'string' }, description: 'New tags (replaces the old list)' },
          mood: { type: 'string', description: 'New mood' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'delete_journal_entry',
      description: 'Delete a journal entry by id or title. Asks for confirmation first (re-call with confirm:true).',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Entry id from get_journal_entries or search_journal_entries' },
          title: { type: 'string', description: 'Entry title to match (when id is not known)' },
          confirm: { type: 'boolean', description: 'Set true to confirm deletion' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_trips',
      description: 'Read trips from the travel planner. Use when they ask about upcoming trips or travel plans.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'number', description: 'Max trips (default 5, max 10)' },
        },
      },
    },
  },
];

function selectToolsForRequest(reqFeature, userMsg) {
  if (reqFeature === 'guardian') {
    const allowed = new Set(['set_mood', 'save_to_starlight_jar', 'remember_fact', 'get_xp_stats']);
    return MOTCHI_TOOLS.filter(t => allowed.has(t.function.name));
  }
  if (reqFeature === 'study') {
    const allowed = new Set(['web_search', 'read_web_page', 'remember_fact', 'read_memories', 'search_books']);
    return MOTCHI_TOOLS.filter(t => allowed.has(t.function.name));
  }
  const trimmed = String(userMsg || '').trim().toLowerCase();
  const isPureGreeting = /^(hi|hello|hey|good morning|good afternoon|good evening|good night|mew|prr|nya|love you|i love you|we love you)[!.,\s]*$/i.test(trimmed);
  if (isPureGreeting) {
    // A bare greeting never needs tools — answer warm and free.
    // Compound asks ("hi, remember X") don't match, so they keep
    // full tools. Both request builders omit `tools`/`tool_choice`
    // entirely when this list is empty.
    return [];
  }
  const isSmallTalk = /^(thanks|thank you|thx|ok(ay)?|haha+|lol|lmao|aw+|cute|nice|cool|great|good|yay|np|you'?re welcome|how are you|how('| i)s it going|what'?s up)[!.,\s?]*$/i.test(trimmed);
  if (isSmallTalk) {
    const coreAllowed = new Set(CORE_TOOLS);
    return MOTCHI_TOOLS.filter(t => coreAllowed.has(t.function.name));
  }
  // Intent routing: core tools + only the groups the message asks
  // for (typically 10-15 of 50 schemas). Falls back to full tools if
  // the router ever returns nothing, so Motchi never goes blind.
  try {
    const wanted = new Set(selectToolNames(userMsg));
    const routed = MOTCHI_TOOLS.filter(t => wanted.has(t.function.name));
    if (routed.length > 0) return routed;
  } catch (_) {}
  return MOTCHI_TOOLS;
}

module.exports = {
  MOTCHI_TOOLS,
  selectToolsForRequest,
};
