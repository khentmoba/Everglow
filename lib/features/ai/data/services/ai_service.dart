import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/ai_conversation.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../cinema/data/models/media_item.dart';

/// Core service for all AI interactions in Everglow.
///
/// Handles conversation history, context gathering from Firestore,
/// permanent memory (facts the AI learns from conversations), and
/// proxied calls to OpenRouter via the Cloud Function.
class AIService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Feature-specific conversation caches
  AIConversation? _assistantConversation;
  AIConversation? _guardianConversation;
  AIConversation? _recommendationConversation;
  AIConversation? _dateIdeaConversation;

  // Permanent memory cache (loaded once per session)
  List<String> _memories = [];
  bool _memoriesLoaded = false;

  bool _isLoading = false;
  String? _lastError;
  String _draftResponse = '';

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  String get draftResponse => _draftResponse;
  List<String> get memories => List.unmodifiable(_memories);

  // ─── Conversation Getters ─────────────────────────────────────

  AIConversation? get assistantConversation => _assistantConversation;
  AIConversation? get guardianConversation => _guardianConversation;

  // ─── Core: Send a message to the AI ────────────────────────────

  Future<String> sendMessage({
    required String feature,
    required String message,
    String? contextOverride,
    bool stream = false,
    String? callerName, // 'khentsgdz' or 'clairjassen'
  }) async {
    _isLoading = true;
    _lastError = null;
    _draftResponse = '';

    // Determine who's chatting
    final caller = callerName ?? _auth.currentUser?.uid ?? 'unknown';
    final isKhent = caller == 'khentsgdz';
    final callerLabel = isKhent ? 'Dada' : 'Mama';

    try {
      final conversation = await _getOrCreateConversation(feature);

      // For assistant: on first message of fresh session, load last session's history
      if (feature == 'assistant' && conversation.messages.isEmpty) {
        await _loadSessionIntoConversation(conversation);
      }

      // Add user message BEFORE notifying so the UI shows it immediately
      conversation.messages.add(AIMessage(role: 'user', content: message));
      _setConversation(feature, conversation);
      notifyListeners();

      // Auto-save to Starlight Jar if user asks Mochi to save something
      if (feature == 'assistant') {
        final lowerMsg = message.toLowerCase();
        final saveTriggers = ['save this', 'write this down', 'save to starlight', 'starlight jar'];
        final shouldSave = saveTriggers.any((t) => lowerMsg.contains(t));
        if (shouldSave && message.length > 10) {
          // Extract the content to save (everything after the trigger)
          String noteContent = message;
          for (final trigger in saveTriggers) {
            noteContent = noteContent.replaceFirst(RegExp(RegExp.escape(trigger), caseSensitive: false), '').trim();
          }
          if (noteContent.length > 5) {
            await writeStarlightNote(noteContent);
          }
        }
      }

      // Gather context if not overridden
      String context = contextOverride ?? await _gatherContext(feature);

      // Prepend who's talking so Mochi knows
      final identityContext = 'The one talking to you now is **$callerLabel** ($caller). '
          '${isKhent ? "You belong to Dada (Khent)." : "You belong to Mama (Clair)."}';
      context = '$identityContext\n\n$context';

      // Load permanent memories
      await _ensureMemoriesLoaded();

      // Build the API messages payload (last 20 messages)
      final recentMessages = conversation.messages
          .map((m) => m.toApiPayload())
          .toList();

      String reply;

      if (stream) {
        // ── Streaming mode ─────────────────────────────
        reply = await _callProxyAIStream(recentMessages, context, _memories, (
          chunk,
        ) {
          _draftResponse += chunk;
          notifyListeners();
        });
        _draftResponse = '';
      } else {
        // ── Non-streaming mode ─────────────────────────
        reply = await _callProxyAI(recentMessages, context, _memories);
      }

      // Add assistant reply
      conversation.messages.add(AIMessage(role: 'assistant', content: reply));

      // Persist to Firestore (keep last 50 messages max)
      if (conversation.messages.length > 50) {
        conversation.messages.removeRange(0, conversation.messages.length - 50);
      }
      await _saveConversation(conversation);

      // Update cache
      _setConversation(feature, conversation);

      // After every exchange, try to extract and save new memories
      await _extractAndSaveMemories(message, reply);

      _isLoading = false;
      notifyListeners();
      return reply;
    } catch (e) {
      _isLoading = false;
      _draftResponse = '';
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Send a message without persisting to conversation history (for one-shot queries).
  Future<String> quickAsk({
    required String message,
    String? context,
    String systemPrompt =
        'You are the Everglow AI — a helpful, loving assistant for Khent and Clair. Be warm, insightful, and concise.',
  }) async {
    try {
      final contextData = context ?? '';
      final systemMsg = contextData.isNotEmpty
          ? '$systemPrompt\n\nContext:\n$contextData'
          : systemPrompt;

      final messages = [
        {'role': 'user', 'content': message},
      ];

      await _ensureMemoriesLoaded();

      final idToken = await _auth.currentUser?.getIdToken() ?? '';

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'systemPrompt': systemMsg,
          'messages': messages,
          'context': contextData,
          'memories': _memories,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? '';
      }

      String errorMsg;
      try {
        final errorData = jsonDecode(response.body);
        errorMsg = errorData['error'] ?? 'Unknown error';
      } catch (_) {
        errorMsg = 'AI service returned ${response.statusCode}';
      }
      throw Exception(errorMsg);
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  // ─── Feature-Specific Methods ──────────────────────────────────

  Future<String> getRecommendation({String? mood}) async {
    final moodContext = mood != null ? "My mood: $mood" : '';
    final prompt =
        'Based on what we\'ve been watching (check my Firestore watchlist data above), what should we watch next? Give 1-3 recommendations with reasons. $moodContext';
    return sendMessage(feature: 'recommendations', message: prompt);
  }

  Future<String> generateDateIdea({
    String? mood,
    String? timeOfDay,
    String? interests,
  }) async {
    final prompt = [
      'Give me a unique date idea for me and my partner.',
      if (mood != null) 'Current mood: $mood',
      if (timeOfDay != null) 'Time: $timeOfDay',
      if (interests != null) 'We enjoy: $interests',
      'Make it romantic and personalized to us.',
    ].join('\n');
    return sendMessage(feature: 'date_ideas', message: prompt);
  }

  Future<String> guardianChat(String message) async {
    return sendMessage(
      feature: 'guardian',
      message: message,
      contextOverride:
          'You are Mochi 🍡 — the magical white cat who lives inside Everglow and watches over Khent and Clair. Your Guardian form appears as a cute floating cat on the dashboard. Speak in short, warm, playful messages. Keep responses under 3 sentences. Use emojis sometimes.',
    );
  }

  // ─── Permanent Memory System ───────────────────────────────────

  /// Load memories from Firestore (once per session).
  Future<void> _ensureMemoriesLoaded() async {
    if (_memoriesLoaded) return;

    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('facts')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      _memories = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return data['fact'] as String? ?? '';
          })
          .where((f) => f.isNotEmpty)
          .toList();
      _memoriesLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load memories: $e');
      _memoriesLoaded = true;
    }
  }

  /// After each exchange, check if the user said something worth
  /// remembering permanently, and save it to the shared memory pool.
  Future<void> _extractAndSaveMemories(
    String userMessage,
    String aiReply,
  ) async {
    final username = _auth.currentUser?.uid != null ? 'the user' : 'user';
    if (_auth.currentUser?.uid == null) return;

    // Keywords that suggest the user is sharing a preference or fact
    final memoryTriggers = [
      'remember',
      'i prefer',
      'i like',
      'i love',
      'i hate',
      'my favorite',
      'my fav',
      'i want',
      'i need',
      'don\'t forget',
      'always',
      'never',
      'important',
      'note that',
      'fyi',
      'i usually',
      'i always',
      'i never',
      'we should',
      'i don\'t like',
      'i\'m afraid of',
      'i\'m scared',
    ];

    final lowerMsg = userMessage.toLowerCase();
    final shouldRemember = memoryTriggers.any((t) => lowerMsg.contains(t));

    if (!shouldRemember) return;

    // Check for duplicate
    final candidate = userMessage.trim();
    if (candidate.length < 5 || _memories.contains(candidate)) return;

    try {
      await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('facts')
          .add({
            'fact': candidate,
            'addedBy': _auth.currentUser?.uid ?? 'unknown',
            'createdAt': FieldValue.serverTimestamp(),
          });
      _memories.insert(0, candidate);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save memory: $e');
    }
  }

  /// Manually save a fact to memory.
  Future<void> saveMemory(String fact) async {
    if (fact.trim().isEmpty) return;

    try {
      await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('facts')
          .add({
            'fact': fact.trim(),
            'addedBy': _auth.currentUser?.uid ?? 'unknown',
            'createdAt': FieldValue.serverTimestamp(),
          });
      _memories.insert(0, fact.trim());
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save memory: $e');
    }
  }

  /// Delete a specific memory.
  Future<void> deleteMemory(String factId) async {
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('facts')
          .where('fact', isEqualTo: factId)
          .limit(1)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        _memories.remove(factId);
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to delete memory: $e');
    }
  }

  // ─── Starlight Jar Write Access ────────────────────────────────

  /// Mochi writes a note to the Starlight Jar.
  Future<void> writeStarlightNote(String content, {String? author}) async {
    try {
      final uid = author ?? _auth.currentUser?.uid ?? 'mochi';
      final username = uid == 'khentsgdz' ? 'khentsgdz'
          : uid == 'clairjassen' ? 'clairjassen'
          : 'mochi';
      await _db.collection('starlight_jar').add({
        'content': content,
        'author': username,
        'timestamp': FieldValue.serverTimestamp(),
        'writtenBy': 'Mochi 🍡',
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to write starlight note: $e');
    }
  }

  // ─── Proactive Nudges & Countdowns ─────────────────────────────

  /// Build time-sensitive context (nudges, countdowns, etc.)
  String _getProactiveContext() {
    final now = DateTime.now();
    final parts = <String>[];

    // Anniversary countdown (Feb 14)
    final anniversary = DateTime(now.year, 2, 14);
    final annivDays = anniversary.difference(now).inDays;
    if (annivDays > 0) {
      parts.add('💕 Anniversary in $annivDays days (Feb 14) — consider romantic date ideas!');
    } else if (annivDays == 0) {
      parts.add('💕 IT\'S ANNIVERSARY DAY! Congratulate them!');
    } else if (annivDays > -7) {
      parts.add('💕 Anniversary was ${-annivDays} days ago — it\'s still fine to mention it!');
    }

    // Khent's birthday (Oct 26)
    final khentBday = DateTime(now.year, 10, 26);
    final khentDays = khentBday.difference(now).inDays;
    if (khentDays > 0 && khentDays <= 14) {
      parts.add('🎂 Dada\'s birthday (Oct 26) is in $khentDays days!');
    } else if (khentDays == 0) {
      parts.add('🎂 DADA\'S BIRTHDAY TODAY! Wish Khent a happy birthday! 🎉');
    }

    // Clair's birthday (Feb 21)
    final clairBday = DateTime(now.year, 2, 21);
    final clairDays = clairBday.difference(now).inDays;
    if (clairDays > 0 && clairDays <= 14) {
      parts.add('🎂 Mama\'s birthday (Feb 21) is in $clairDays days!');
    } else if (clairDays == 0) {
      parts.add('🎂 MAMA\'S BIRTHDAY TODAY! Wish Clair a happy birthday! 🎉');
    }

    // Time of day greeting
    final hour = now.hour;
    if (hour < 12) {
      parts.add('🌅 It\'s morning — wish them a good day!');
    } else if (hour < 17) {
      parts.add('☀️ Afternoon vibes.');
    } else if (hour < 21) {
      parts.add('🌙 Evening time — maybe suggest a cozy activity?');
    } else {
      parts.add('🌃 Night time — suggest winding down or stargazing!');
    }

    return parts.isNotEmpty ? parts.join('\n') : '';
  }

  // ─── Context Gathering ─────────────────────────────────────────

  Future<String> _gatherContext(String feature) async {
    final parts = <String>[];

    try {
      switch (feature) {
        case 'assistant':
          // Full context for the assistant
          parts.add(_getProactiveContext()); // countdowns, nudges
          parts.add(await _getDailyDigest());
          parts.add(await _getMoodContext());
          parts.add(await _getWatchContext());
          parts.add(await _getBooksContext());
          parts.add(await _getStarlightContext());
          parts.add(await _getRecentChatContext());
          parts.add(await _getMusicContext());
          parts.add(await _getGardenContext());
          parts.add(await _getCanvasContext());
          parts.add(await _getPlayZoneContext());
          parts.add(await _getRelationshipStats());
          parts.add(await _getRecentActivity());
          // Session history so Mochi remembers past conversations
          parts.add(await _getSessionHistoryContext());
          break;
        case 'guardian':
          parts.add(await _getMoodContext());
          break;
        case 'recommendations':
          parts.add(await _getWatchContext());
          parts.add(await _getBooksContext());
          break;
        case 'date_ideas':
          parts.add(await _getMoodContext());
          parts.add(await _getStarlightContext());
          break;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AIService context error: $e');
    }

    return parts.where((p) => p.isNotEmpty).join('\n\n');
  }

  // ─── Context: Moods ───────────────────────────────────────────

  Future<String> _getMoodContext() async {
    try {
      // Get both partners' moods
      final usernames = ['khentsgdz', 'clairjassen'];
      final parts = <String>[];

      for (final username in usernames) {
        final snapshot = await _db
            .collection('moods')
            .where('username', isEqualTo: username)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final moods = snapshot.docs
              .map((doc) {
                final data = doc.data();
                final emoji = data['moodEmoji'] ?? '😊';
                final label = data['moodLabel'] ?? 'okay';
                final ts = data['createdAt'] as Timestamp?;
                final date = ts?.toDate();
                final dateStr = date != null
                    ? '${date.month}/${date.day}'
                    : 'recently';
                return '$emoji $label ($dateStr)';
              })
              .join(', ');
          parts.add('$username: $moods');
        }
      }

      return parts.isEmpty ? '' : 'Recent moods:\n${parts.join('\n')}';
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Watchlist / Cinema ───────────────────────────────

  Future<String> _getWatchContext() async {
    try {
      final parts = <String>[];

      for (final username in ['khentsgdz', 'clairjassen']) {
        final snapshot = await _db
            .collection('our_cinema')
            .where('userId', isEqualTo: username)
            .orderBy('addedAt', descending: true)
            .limit(15)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final items = snapshot.docs
              .map((doc) {
                final data = doc.data();
                final title = data['title'] ?? 'Unknown';
                final type = data['mediaType'] ?? 'movie';
                final status = data['status'] ?? 'plan to watch';
                return '$title ($type) - $status';
              })
              .join('\n');
          parts.add('$username\'s watchlist:\n$items');
        }
      }

      return parts.isEmpty ? '' : parts.join('\n\n');
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Books ───────────────────────────────────────────

  Future<String> _getBooksContext() async {
    try {
      final snapshot = await _db.collection('our_books').limit(20).get();
      if (snapshot.docs.isEmpty) return '';

      final books = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final title = data['title'] ?? 'Unknown';
            final author = data['author'] ?? '';
            final addedBy = data['addedBy'] ?? '';
            final readBy = <String>[];
            if (data['khentReadAt'] != null) readBy.add('Khent');
            if (data['clairReadAt'] != null) readBy.add('Clair');
            final readStr = readBy.isNotEmpty
                ? ' [read by ${readBy.join(', ')}]'
                : '';
            return '$title by $author (added by $addedBy)$readStr';
          })
          .join('\n');

      return 'Books:\n$books';
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Starlight Jar Notes ─────────────────────────────

  Future<String> _getStarlightContext() async {
    try {
      final snapshot = await _db
          .collection('starlight_jar')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (snapshot.docs.isEmpty) return '';

      final notes = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final content = data['content'] ?? '';
            final author = data['author'] ?? '';
            return '- "$content" — $author';
          })
          .join('\n');

      return 'Starlight Jar notes (recent):\n$notes';
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Recent Chat Messages ────────────────────────────

  Future<String> _getRecentChatContext() async {
    try {
      final snapshot = await _db
          .collection('sanctuary_messages')
          .orderBy('timestamp', descending: true)
          .limit(15)
          .get();

      if (snapshot.docs.isEmpty) return '';

      // Reverse so chronological order
      final docs = snapshot.docs.toList().reversed;
      final messages = docs
          .map((doc) {
            final data = doc.data();
            final sender = data['sender'] ?? 'unknown';
            final text = data['text'] ?? '';
            // Truncate long messages
            final truncated = text.length > 80
                ? '${text.substring(0, 80)}…'
                : text;
            return '$sender: $truncated';
          })
          .join('\n');

      return 'Recent chat messages:\n$messages';
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Music / Jukebox ─────────────────────────────────

  Future<String> _getMusicContext() async {
    try {
      final parts = <String>[];

      for (final username in ['khentsgdz', 'clairjassen']) {
        final doc = await _db.collection('music_status').doc(username).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final track = data['trackName'] ?? '';
          final artist = data['artistName'] ?? '';
          final isPlaying = data['isPlaying'] ?? false;
          if (track.isNotEmpty) {
            final status = isPlaying ? '🎵 Now playing' : 'Last played';
            parts.add('$username: $status — "$track" by $artist');
          }
        }
      }

      return parts.isEmpty ? '' : 'Music:\n${parts.join('\n')}';
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Garden / Daily Bloom ────────────────────────────

  Future<String> _getGardenContext() async {
    try {
      final parts = <String>[];

      for (final username in ['khentsgdz', 'clairjassen']) {
        // Need to get UID first
        final userDoc = await _db
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();

        if (userDoc.docs.isEmpty) continue;
        final uid = userDoc.docs.first.id;

        final gardenDoc = await _db
            .collection('users')
            .doc(uid)
            .collection('garden_stats')
            .doc('stats')
            .get();

        if (gardenDoc.exists && gardenDoc.data() != null) {
          final data = gardenDoc.data()!;
          final stage = data['currentStage'] ?? 0;
          final streak = data['streakCount'] ?? 0;
          final total = data['totalInteractions'] ?? 0;
          final stageNames = [
            'dormant',
            'seed',
            'sprout',
            'budding',
            'blooming',
            'full bloom',
          ];
          final stageName = stage < stageNames.length
              ? stageNames[stage]
              : 'stage $stage';
          parts.add(
            '$username: $stageName garden, $streak day streak, $total total visits',
          );
        }
      }

      return parts.isEmpty ? '' : 'Garden status:\n${parts.join('\n')}';
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Recent Activity ─────────────────────────────────

  Future<String> _getRecentActivity() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return '';

    try {
      final xpSnapshot = await _db
          .collection('xp')
          .doc(uid)
          .collection('log')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (xpSnapshot.docs.isEmpty) return '';

      final activities = xpSnapshot.docs
          .map((doc) {
            final data = doc.data();
            return '${data['action'] ?? 'activity'} on ${data['timestamp']?.toDate()?.toString().substring(0, 10) ?? 'recently'}';
          })
          .join('\n');

      return 'Recent activity:\n$activities';
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Canvas ───────────────────────────────────────────

  Future<String> _getCanvasContext() async {
    try {
      final snapshot = await _db
          .collection('canvas_strokes')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      if (snapshot.docs.isEmpty) return '';
      final strokes = snapshot.docs.map((d) {
        final data = d.data();
        final author = data['author'] ?? 'someone';
        final ts = data['timestamp'] as Timestamp?;
        final date = ts?.toDate();
        return '$author drew on ${date?.toString().substring(0, 10) ?? 'recently'}';
      }).join('\n');
      return 'Canvas drawings:\n$strokes';
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Play Zone ────────────────────────────────────────

  Future<String> _getPlayZoneContext() async {
    try {
      final snapshot = await _db
          .collection('tt_rooms')
          .orderBy('updatedAt', descending: true)
          .limit(5)
          .get();
      if (snapshot.docs.isEmpty) return '';
      final games = snapshot.docs.map((d) {
        final data = d.data();
        final hostScore = data['hostScore']?.toString() ?? '0';
        final guestScore = data['guestScore']?.toString() ?? '0';
        final status = data['status'] ?? 'unknown';
        return 'Table tennis: $hostScore-$guestScore ($status)';
      }).join('\n');
      return 'Recent games:\n$games';
    } catch (_) {
      return '';
    }
  }

  // ─── Context: Relationship Stats ───────────────────────────────

  Future<String> _getRelationshipStats() async {
    try {
      final parts = <String>[];

      // XP levels
      for (final username in ['khentsgdz', 'clairjassen']) {
        final userDoc = await _db
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
        if (userDoc.docs.isEmpty) continue;
        final uid = userDoc.docs.first.id;
        final progressDoc =
            await _db.collection('users').doc(uid).collection('progress').doc('main').get();
        if (progressDoc.exists && progressDoc.data() != null) {
          final data = progressDoc.data()!;
          final level = data['level'] ?? 1;
          final xp = data['xpTotal'] ?? 0;
          final streak = data['streak'] ?? 0;
          final label = username == 'khentsgdz' ? 'Dada' : 'Mama';
          parts.add('$label: Level $level, $xp XP, $streak day streak');
        }
      }

      // Total watch count
      for (final username in ['khentsgdz', 'clairjassen']) {
        final watchSnapshot = await _db
            .collection('our_cinema')
            .where('userId', isEqualTo: username)
            .where('status', isEqualTo: 'watched')
            .count()
            .get();
        final count = watchSnapshot.count ?? 0;
        final label = username == 'khentsgdz' ? 'Dada' : 'Mama';
        if (count > 0) parts.add('$label has watched $count movies/series');
      }

      return parts.isNotEmpty ? 'Relationship stats:\n${parts.join('\n')}' : '';
    } catch (_) {
      return '';
    }
  }

  // ─── Daily Digest ──────────────────────────────────────────────

  /// A morning/evening digest that Mochi can use to greet you.
  Future<String> _getDailyDigest() async {
    final now = DateTime.now();
    final parts = <String>[];

    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    parts.add('$greeting!');

    // Birthday countdowns
    final khentBday = DateTime(now.year, 10, 26);
    final clairBday = DateTime(now.year, 2, 21);
    final anniv = DateTime(now.year, 2, 14);
    final daysToKhent = khentBday.difference(now).inDays;
    final daysToClair = clairBday.difference(now).inDays;
    final daysToAnniv = anniv.difference(now).inDays;

    if (daysToKhent == 0) parts.add('🎂 Dada\'s birthday TODAY!');
    else if (daysToKhent > 0 && daysToKhent <= 30) parts.add('Dada\'s birthday in $daysToKhent days 🎂');
    if (daysToClair == 0) parts.add('🎂 Mama\'s birthday TODAY!');
    else if (daysToClair > 0 && daysToClair <= 30) parts.add('Mama\'s birthday in $daysToClair days 🎂');
    if (daysToAnniv == 0) parts.add('💕 ANNIVERSARY TODAY!');
    else if (daysToAnniv > 0 && daysToAnniv <= 30) parts.add('Anniversary in $daysToAnniv days 💕');

    return 'Today\'s digest: ${parts.join(' ')}';
  }

  // ─── Cloud Function Call ───────────────────────────────────────

  String get _cloudFunctionUrl {
    if (kIsWeb) return '${Uri.base.origin}/api/proxyAI';
    if (kDebugMode) {
      return 'http://127.0.0.1:5001/everglow-1c6db/us-central1/proxyAI';
    }
    return 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyAI';
  }

  Future<String> _callProxyAI(
    List<Map<String, dynamic>> messages,
    String context,
    List<String> memories,
  ) async {
    final idToken = await _auth.currentUser?.getIdToken() ?? '';

    final response = await http
        .post(
          Uri.parse(_cloudFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'messages': messages,
            'context': context,
            'memories': memories,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['reply'] as String? ?? '';
    }

    String errorMsg;
    try {
      final errorData = jsonDecode(response.body);
      errorMsg = errorData['error'] ?? 'Unknown error';
    } catch (_) {
      errorMsg = 'AI service returned ${response.statusCode}';
    }
    throw Exception(errorMsg);
  }

  /// Stream a response from the AI, calling [onChunk] with each piece.
  Future<String> _callProxyAIStream(
    List<Map<String, dynamic>> messages,
    String context,
    List<String> memories,
    void Function(String chunk) onChunk,
  ) async {
    final idToken = await _auth.currentUser?.getIdToken() ?? '';
    final url = _cloudFunctionUrl;
    final body = jsonEncode({
      'messages': messages,
      'context': context,
      'memories': memories,
      'stream': true,
    });

    final fullResponse = StringBuffer();

    final http.Response response = await http
        .post(
          Uri.parse('$url?stream=true'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 65));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = data['reply'] as String? ?? '';
      if (reply.isNotEmpty) {
        // Stream the reply character by character for visual effect
        for (var i = 0; i < reply.length; i++) {
          fullResponse.write(reply[i]);
          onChunk(reply[i]);
          await Future.delayed(const Duration(milliseconds: 15));
        }
      }
      return fullResponse.toString();
    }

    String errorMsg;
    try {
      final errorData = jsonDecode(response.body);
      errorMsg = errorData['error'] ?? 'Unknown error';
    } catch (_) {
      errorMsg = 'AI service returned ${response.statusCode}';
    }
    throw Exception(errorMsg);
  }

  // ─── Firestore Persistence ─────────────────────────────────────

  Future<AIConversation> _getOrCreateConversation(String feature) async {
    final cached = _getConversation(feature);
    if (cached != null) return cached;

    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      final conv = AIConversation(
        id: 'local_${feature}_${DateTime.now().millisecondsSinceEpoch}',
        feature: feature,
      );
      _setConversation(feature, conv);
      return conv;
    }

    try {
      final docRef = _db
          .collection('users')
          .doc(uid)
          .collection('ai_conversations')
          .doc(feature);

      final doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final conv = AIConversation.fromJson(doc.data()!);
        _setConversation(feature, conv);
        return conv;
      }
    } catch (_) {}

    final conv = AIConversation(id: feature, feature: feature);
    _setConversation(feature, conv);
    return conv;
  }

  Future<void> _saveConversation(AIConversation conversation) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('ai_conversations')
          .doc(conversation.id)
          .set(conversation.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save AI conversation: $e');
    }
  }

  AIConversation? _getConversation(String feature) {
    switch (feature) {
      case 'assistant':
        return _assistantConversation;
      case 'guardian':
        return _guardianConversation;
      case 'recommendations':
        return _recommendationConversation;
      case 'date_ideas':
        return _dateIdeaConversation;
      default:
        return null;
    }
  }

  void _setConversation(String feature, AIConversation? conv) {
    switch (feature) {
      case 'assistant':
        _assistantConversation = conv;
        break;
      case 'guardian':
        _guardianConversation = conv;
        break;
      case 'recommendations':
        _recommendationConversation = conv;
        break;
      case 'date_ideas':
        _dateIdeaConversation = conv;
        break;
    }
  }

  Future<void> clearConversation(String feature) async {
    // Archive the session before clearing
    final conv = _getConversation(feature);
    if (conv != null && conv.messages.length >= 2) {
      await _archiveSession(conv);
    }

    _setConversation(feature, null);
    notifyListeners();

    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('ai_conversations')
          .doc(feature)
          .delete();
    } catch (_) {}
  }

  // Session history cache
  List<String> _sessionSummaries = [];
  List<AIConversation> _recentSessions = [];
  bool _sessionHistoryLoaded = false;

  // ─── Start Fresh Session (archives previous) ───────────────────

  /// Start a fresh session — clears conversation but doesn't archive.
  /// Previous session stays visible when you reopen the chat.
  void startFreshSession() {
    _assistantConversation = null;
    _guardianConversation = null;
    _recommendationConversation = null;
    _dateIdeaConversation = null;
    notifyListeners();
  }

  /// Reset memory cache (call on logout).
  void resetMemories() {
    _memories = [];
    _memoriesLoaded = false;
    _sessionSummaries = [];
    _recentSessions = [];
    _sessionHistoryLoaded = false;
  }

  // ─── Session History (Hybrid Memory) ───────────────────────────

  /// Archive the current conversation as a session and manage old ones.
  Future<void> _archiveSession(AIConversation conversation) async {
    try {
      final messagesJson = conversation.messages
          .map((m) => m.toJson())
          .toList();

      // Save full session
      await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .add({
            'feature': conversation.feature,
            'messages': messagesJson,
            'messageCount': messagesJson.length,
            'hasSummary': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Check if we have too many full sessions — summarize oldest
      await _trimFullSessions();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to archive session: $e');
    }
  }

  /// Keep max 3 full sessions; older ones get summarized.
  Future<void> _trimFullSessions() async {
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .where('hasSummary', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.length <= 3) return;

      // Summarize the oldest full sessions (all beyond the 3 most recent)
      final toSummarize = snapshot.docs.toList().skip(3).toList();
      for (final doc in toSummarize) {
        final data = doc.data();
        final messages = data['messages'] as List? ?? [];
        final summary = _buildLocalSummary(messages);
        await doc.reference.update({
          'hasSummary': true,
          'summary': summary,
          'messages': [], // Clear messages to save space
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to trim sessions: $e');
    }
  }

  /// Build a simple text summary from session messages.
  String _buildLocalSummary(List messages) {
    if (messages.isEmpty) return 'Empty session';

    final topics = <String>[];
    for (final msg in messages) {
      final m = msg as Map<String, dynamic>;
      final content = (m['content'] as String? ?? '').trim();
      if (content.length > 10 && !topics.contains(content.substring(0, 30))) {
        topics.add(
          content.length > 60 ? '${content.substring(0, 60)}…' : content,
        );
      }
    }
    return topics.take(5).join(' | ');
  }

  /// Load session history: summaries of old sessions + last 3 full.
  Future<void> _loadSessionHistory() async {
    if (_sessionHistoryLoaded) return;

    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      _sessionSummaries = [];
      _recentSessions = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final hasSummary = data['hasSummary'] as bool? ?? false;

        if (hasSummary) {
          final summary = data['summary'] as String? ?? '';
          if (summary.isNotEmpty) _sessionSummaries.add(summary);
        } else {
          // Full session — reconstruct conversation
          final msgsJson = data['messages'] as List? ?? [];
          final msgs = msgsJson
              .map((m) => AIMessage.fromJson(m as Map<String, dynamic>))
              .toList();
          final conv = AIConversation(
            id: doc.id,
            feature: data['feature'] as String? ?? 'assistant',
            messages: msgs,
          );
          _recentSessions.add(conv);
        }
      }
      _sessionHistoryLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load sessions: $e');
      _sessionHistoryLoaded = true;
    }
  }

  /// Load the last session's messages into the current conversation
  /// so the user sees their past chat history after sending a message.
  Future<void> _loadSessionIntoConversation(AIConversation conversation) async {
    try {
      final snapshot = await _db
          .collection('ai_memories')
          .doc('shared')
          .collection('sessions')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return;

      final data = snapshot.docs.first.data();
      final hasSummary = data['hasSummary'] as bool? ?? true;
      if (hasSummary) return; // Only load full sessions, not summarized ones

      final msgsJson = data['messages'] as List? ?? [];
      if (msgsJson.isEmpty) return;

      final pastMessages = msgsJson
          .map((m) => AIMessage.fromJson(m as Map<String, dynamic>))
          .toList();

      // Prepend past messages to current conversation
      conversation.messages.insertAll(0, pastMessages);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load last session: $e');
    }
  }

  /// Format session history as text for the AI context.
  Future<String> _getSessionHistoryContext() async {
    await _loadSessionHistory();

    final parts = <String>[];

    // Summaries of old sessions
    if (_sessionSummaries.isNotEmpty) {
      parts.add(
        'Past session summaries (older conversations):\n${_sessionSummaries.take(5).map((s) => '- $s').join('\n')}',
      );
    }

    // Last 3 full sessions
    if (_recentSessions.isNotEmpty) {
      final recentParts = _recentSessions
          .take(3)
          .map((session) {
            final msgs = session.messages
                .map((m) {
                  final who = m.role == 'user' ? 'User' : 'Mochi';
                  return '$who: ${m.content}';
                })
                .join('\n');
            return msgs;
          })
          .join('\n\n---\n\n');
      parts.add('Previous conversations (recent):\n$recentParts');
    }

    return parts.join('\n\n');
  }
}
