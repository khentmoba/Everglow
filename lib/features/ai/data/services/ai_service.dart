import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/ai_conversation.dart';
import 'ai_memory_repo.dart';
import 'ai_conversation_repo.dart';
import '../../domain/repositories/ai_memory_repo_interface.dart';
import '../../domain/repositories/ai_conversation_repo_interface.dart';
import 'sse_streamer.dart';

/// Core service for all AI interactions in Everglow.
///
/// Coordinates conversation, memory, and API calls by delegating to
/// focused repositories and the Cloud Function proxy.
class AIService extends ChangeNotifier {
  final IAIMemoryRepository _memoryRepo;
  final IAIConversationRepository _conversationRepo;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AIService({
    IAIMemoryRepository? memoryRepo,
    IAIConversationRepository? conversationRepo,
  }) : _memoryRepo = memoryRepo ?? AIMemoryRepository(),
       _conversationRepo = conversationRepo ?? AIConversationRepository();

  // Convenience helpers
  List<String> get memories => _memoryRepo.all;
  AIConversation? get assistantConversation => _conversationRepo.assistant;
  AIConversation? get guardianConversation => _conversationRepo.guardian;

  bool _isLoading = false;
  String? _lastError;
  String _draftResponse = '';
  String _draftReasoning = '';
  String _toolStatus = '';

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  String get draftResponse => _draftResponse;
  String get draftReasoning => _draftReasoning;
  String get toolStatus => _toolStatus;

  // ─── Core: Send a message to the AI ────────────────────────────

  Future<String> sendMessage({
    required String feature,
    required String message,
    String? contextOverride,
    bool stream = false,
    bool enableThinking = true,
    String? callerName, // 'khentsgdz' or 'clairjassen'
    void Function(String toolStatus)? onToolStatus,
    List<String> imageUrls = const [],
  }) async {
    _isLoading = true;
    _lastError = null;
    _draftResponse = '';
    _draftReasoning = '';
    _toolStatus = '';

    AIConversation? conversation;

    // Determine who's chatting
    final caller = callerName ?? _auth.currentUser?.uid ?? 'unknown';

    try {
      conversation = await _getOrCreateConversation(feature);

      // For assistant: on first message of fresh session, load last session's history
      if (feature == 'assistant' && conversation.messages.isEmpty) {
        await _loadSessionIntoConversation(conversation);
      }

      // Add user message BEFORE notifying so the UI shows it immediately
      conversation.messages.add(AIMessage(
        role: 'user',
        content: message,
        imageUrls: imageUrls,
      ));
      _setConversation(feature, conversation);
      notifyListeners();

      // Gather context: if contextOverride is set, use it directly.
      // Otherwise, pass feature + caller to the server so it builds context
      // server-side (Firestore reads from GCP region are near-instant).
      final context = contextOverride ?? ''; // server builds from feature+caller

      // Load permanent memories
      await _ensureMemoriesLoaded();

      // Build the API messages payload (all conversation messages)
      final recentMessages = conversation.messages
          .map((m) => m.toApiPayload())
          .toList();

      String reply;

      if (stream) {
        // ── Streaming mode ─────────────────────────────
        reply = await _callProxyAIStream(
          recentMessages, context, _memoryRepo.all, feature, caller, (
          chunk,
        ) {
          _draftResponse += chunk;
          notifyListeners();
        }, onReasoning: (reasoning) {
          _draftReasoning += reasoning;
          notifyListeners();
        }, onToolStatus: (status) {
          _toolStatus = status;
          notifyListeners();
        }, onError: (error) {
          _lastError = error;
          notifyListeners();
        }, enableThinking: enableThinking);
        _draftResponse = '';
        _draftReasoning = '';
        _toolStatus = '';
      } else {
        // ── Non-streaming mode ─────────────────────────
        reply = await _callProxyAI(recentMessages, context, _memoryRepo.all, feature, caller);
      }

      // Add assistant reply (skip empty replies, e.g. tool-only rounds that
      // produced no visible text).
      if (reply.trim().isNotEmpty) {
        // Strip the model's leading blank lines/whitespace so the reply
        // starts right at the first real line instead of a visible gap.
        final cleaned = reply.trimLeft();
        conversation.messages.add(AIMessage(role: 'assistant', content: cleaned));
      }

      // Publish the finished reply to the UI immediately so the loading
      // state ends as soon as the stream does; Firestore writes below can
      // take seconds and must not hold the chat in "thinking".
      _isLoading = false;
      _draftResponse = '';
      _draftReasoning = '';
      _toolStatus = '';
      _setConversation(feature, conversation);
      notifyListeners();

      // Persist to Firestore (keep last 50 messages max)
      if (conversation.messages.length > 50) {
        conversation.messages.removeRange(0, conversation.messages.length - 50);
      }
      await _saveConversation(conversation);

      // Auto-archive a session snapshot roughly every 20 messages
      if (conversation.messages.length >= 4 &&
          conversation.messages.length % 20 <= 1) {
        // Archive without clearing — preserves history in sessions collection
        try {
          await _archiveSession(conversation);
        } catch (e) {
          debugPrint('[AIService] Session archive failed: $e');
        }
      }

      // After every exchange, try to extract and save new memories (fire-and-forget)
      unawaited(_extractAndSaveMemories(message, reply));

      return reply;
    } catch (e) {
      _isLoading = false;
      _draftResponse = '';
      _draftReasoning = '';
      _toolStatus = '';
      _lastError = e.toString();
      // Roll back the optimistic user message so a retry doesn't duplicate it.
      if (conversation != null &&
          conversation.messages.isNotEmpty &&
          conversation.messages.last.role == 'user' &&
          conversation.messages.last.content == message &&
          conversation.messages.last.imageUrls.length == imageUrls.length) {
        conversation.messages.removeLast();
        _setConversation(feature, conversation);
      }
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
          'memories': _memoryRepo.all,
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
          'You are Mochi 🍡 — the magical white cat who lives inside Everglow and watches over Khent and Clair. Your Guardian form appears as a cute floating cat on the dashboard. Speak in warm, playful, expressive messages. You can be 1-4 sentences depending on what feels right. Use emojis sometimes. Be genuinely helpful — answer questions, give suggestions, check in on how they\'re doing.',
    );
  }

  // ─── Permanent Memory System ───────────────────────────────────

  Future<void> _ensureMemoriesLoaded() => _memoryRepo.load();

  Future<void> _extractAndSaveMemories(String userMessage, String aiReply) async {
    if (_auth.currentUser?.uid == null) return;

    String? fact;
    String category = 'fact';
    try {
      final extracted = await quickAsk(
        message:
            'Extract ONE personal fact about Khent or Clair from this exchange. '
            'Reply in format: CATEGORY|FACT (e.g., "preference|Khent prefers black coffee"). '
            'Categories: fact, preference, dislike, goal, date, habit. '
            'If nothing worth remembering, reply with exactly: NONE\n\n'
            'User: $userMessage\nAssistant: $aiReply',
      );
      fact = extracted.trim();
      if (fact.isEmpty || fact == 'NONE' || fact.length > 200) return;

      // Parse category|fact format
      if (fact.contains('|')) {
        final parts = fact.split('|');
        category = parts[0].trim();
        fact = parts.sublist(1).join('|').trim();
      }
    } catch (_) {
      return;
    }

    if (_memoryRepo.isDuplicate(fact)) return;
    await _memoryRepo.save(fact, category: category);
  }

  Future<void> saveMemory(String fact, {String category = 'fact'}) async {
    await _memoryRepo.save(fact, category: category);
    notifyListeners();
  }

  Future<void> deleteMemory(String factId) async {
    await _memoryRepo.delete(factId);
    notifyListeners();
  }

  void resetMemories() => _memoryRepo.reset();

  // ─── Starlight Jar Write Access ────────────────────────────────

  /// Mochi writes a note to the Starlight Jar.
  Future<void> writeStarlightNote(String content, {String? author}) async {
    try {
      final db = FirebaseFirestore.instance;
      final uid = author ?? _auth.currentUser?.uid ?? 'mochi';
      final username = uid == 'khentsgdz' ? 'khentsgdz'
          : uid == 'clairjassen' ? 'clairjassen'
          : 'mochi';
      await db.collection('starlight_jar').add({
        'content': content,
        'author': username,
        'timestamp': FieldValue.serverTimestamp(),
        'writtenBy': 'Mochi 🍡',
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to write starlight note: $e');
    }
  }

  // ─── Cloud Function Call ───────────────────────────────────────

  String get _cloudFunctionUrl {
    if (kIsWeb) {
      // V2 function (Cloud Run) — supports true SSE streaming
      return 'https://proxyaiv2-6pr4gqobxa-uc.a.run.app';
    }
    if (kDebugMode) {
      return 'http://127.0.0.1:5001/everglow-1c6db/us-central1/proxyAI';
    }
    return 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyAI';
  }

  Future<String> _callProxyAI(
    List<Map<String, dynamic>> messages,
    String context,
    List<String> memories,
    [String feature = '',
    String caller = '',
  ]) async {
    const maxRetries = 2;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await _callProxyAIOnce(messages, context, memories, feature, caller);
      } catch (e) {
        final isTransient = e is SocketException ||
            e is TimeoutException ||
            (e is Exception && e.toString().contains('503')) ||
            (e is Exception && e.toString().contains('502')) ||
            (e is Exception && e.toString().contains('429'));
        if (attempt < maxRetries && isTransient) {
          await Future.delayed(Duration(seconds: 1 << attempt)); // 1s, 2s
          continue;
        }
        rethrow;
      }
    }
    // unreachable
    throw Exception('Retry exhausted');
  }

  Future<String> _callProxyAIOnce(
    List<Map<String, dynamic>> messages,
    String context,
    List<String> memories,
    [String feature = '',
    String caller = '',
  ]) async {
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
            if (feature.isNotEmpty) 'feature': feature,
            if (caller.isNotEmpty) 'caller': caller,
            'enableThinking': true,
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

  /// Stream a response from the AI via real SSE, calling [onChunk] with each
  /// token as the model generates it.
  Future<String> _callProxyAIStream(
    List<Map<String, dynamic>> messages,
    String context,
    List<String> memories,
    String feature,
    String caller,
    void Function(String chunk) onChunk, {
    void Function(String chunk)? onReasoning,
    void Function(String toolStatus)? onToolStatus,
    void Function(String error)? onError,
    bool enableThinking = true,
  }) async {
    const maxRetries = 2;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await _callProxyAIStreamOnce(
          messages,
          context,
          memories,
          feature,
          caller,
          onChunk,
          onReasoning,
          onToolStatus,
          onError,
          enableThinking: enableThinking,
        );
      } catch (e) {
        final isTransient = e is SocketException ||
            e is TimeoutException ||
            (e is Exception && e.toString().contains('503')) ||
            (e is Exception && e.toString().contains('502')) ||
            (e is Exception && e.toString().contains('429'));
        if (attempt < maxRetries && isTransient) {
          await Future.delayed(Duration(seconds: 1 << attempt));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Retry exhausted');
  }

  Future<String> _callProxyAIStreamOnce(
    List<Map<String, dynamic>> messages,
    String context,
    List<String> memories,
    String feature,
    String caller,
    void Function(String chunk) onChunk,
    void Function(String chunk)? onReasoning,
    void Function(String toolStatus)? onToolStatus,
    void Function(String error)? onError,
    {
    bool enableThinking = true,
    }
  ) async {
    final idToken = await _auth.currentUser?.getIdToken() ?? '';
    final body = jsonEncode({
      'messages': messages,
      'context': context,
      'memories': memories,
      'feature': feature,
      'caller': caller,
      'stream': true, // enables real SSE streaming from the backend
      'enableThinking': enableThinking,
    });

    return streamSseResponse(
      url: _cloudFunctionUrl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: body,
      onChunk: onChunk,
      onReasoning: onReasoning,
      onToolStatus: onToolStatus,
      onError: onError,
      timeout: const Duration(seconds: 120),
    );
  }

  // Firestore Persistence

  Future<AIConversation> _getOrCreateConversation(String feature) =>
      _conversationRepo.getOrCreate(feature);

  Future<void> _saveConversation(AIConversation conversation) =>
      _conversationRepo.save(conversation);

  void _setConversation(String feature, AIConversation? conv) =>
      _conversationRepo.setConversation(feature, conv);

  Future<void> clearConversation(String feature) async {
    await _conversationRepo.clear(feature);
    notifyListeners();
  }

  /// Load the assistant conversation on panel open.
  Future<void> loadAssistantConversation() async {
    await _conversationRepo.loadAssistant();
    notifyListeners();
  }

  void startFreshSession() {
    _conversationRepo.startFresh();
    notifyListeners();
  }

  Future<void> _archiveSession(AIConversation conversation) =>
      _conversationRepo.archiveSession(conversation);

  Future<void> _loadSessionIntoConversation(AIConversation conversation) =>
      _conversationRepo.loadSessionIntoConversation(conversation);

  // ─── Session Management ─────────────────────────────────────────

  /// List all archived sessions, newest first.
  Future<List<AISession>> listSessions({int limit = 50}) =>
      _conversationRepo.listSessions(limit: limit);

  /// Switch to a specific archived session, loading its messages.
  Future<void> switchSession(String sessionId) async {
    await _conversationRepo.loadSession(sessionId);
    // Also save it as the current assistant conversation
    final conv = _conversationRepo.assistant;
    if (conv != null) {
      await _conversationRepo.save(conv);
    }
    notifyListeners();
  }

  /// Delete a specific archived session.
  Future<void> deleteSession(String sessionId) =>
      _conversationRepo.deleteSession(sessionId);

  /// Archive the current conversation as a new session.
  Future<void> archiveCurrentSession() async {
    final conv = _conversationRepo.assistant;
    if (conv != null && conv.messages.length >= 2) {
      await _conversationRepo.archiveSession(conv);
    }
  }
}
