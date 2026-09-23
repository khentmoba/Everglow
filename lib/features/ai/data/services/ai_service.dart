import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/ai_conversation.dart';
import '../../domain/motchi_quality.dart';
import 'ai_memory_repo.dart';
import 'ai_conversation_repo.dart';
import '../../domain/repositories/ai_memory_repo_interface.dart';
import '../../domain/repositories/ai_conversation_repo_interface.dart';
import 'sse_streamer.dart';
import 'study_artifact.dart';

/// Core service for all AI interactions in Everglow.
///
/// Coordinates conversation, memory, and API calls by delegating to
/// focused repositories and the Cloud Function proxy.
class AIService extends ChangeNotifier {
  final IAIMemoryRepository _memoryRepo;
  final IAIConversationRepository _conversationRepo;
  // Resolved lazily so AIService can be built with fake repos (tests)
  // without initializing Firebase.
  FirebaseAuth get _auth => FirebaseAuth.instance;

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
  int _activeRequest = 0;
  String? _lastError;
  String _draftResponse = '';
  String _draftReasoning = '';
  // Names of the tools Motchi is running RIGHT NOW. A name is added when
  // its `tool_status` event arrives and removed when its `tool_result`
  // lands — the chat strip shows only in-flight work, never a history.
  List<String> _activeTools = [];

  /// Per-token notifiers so the streaming bubble can repaint without
  /// rebuilding the whole conversation list on every SSE chunk.
  final ValueNotifier<int> draftRevisionNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> draftResponseNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> draftReasoningNotifier = ValueNotifier<String>(
    '',
  );
  final ValueNotifier<List<String>> activeToolsNotifier =
      ValueNotifier<List<String>>(const []);
  final ValueNotifier<List<Map<String, dynamic>>> toolResultsNotifier = ValueNotifier<List<Map<String, dynamic>>>([]);
  List<Map<String, dynamic>> _toolResults = [];
  List<Map<String, dynamic>> get toolResults => List.unmodifiable(_toolResults);
  List<String> get activeTools => List.unmodifiable(_activeTools);

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  String get draftResponse => _draftResponse;
  String get draftReasoning => _draftReasoning;

  /// How many recent messages ride along per request. Older turns live on
  /// in archived sessions + summaries, which the server injects on demand —
  /// resending all 50 stored messages every turn just burns upload bytes
  /// and input tokens on long chats. Matches the ~20-message archive
  /// cadence so live history and archives overlap without gaps.
  static const int historyLimit = 20;

  /// The guardian mascot stays tiny: only the last few turns matter.
  static const int guardianHistoryLimit = 12;

  /// Keeps only the trailing [limit] payloads (returns the list untouched
  /// when it already fits). Pure so the trim rule is unit-testable.
  @visibleForTesting
  static List<Map<String, dynamic>> trimHistoryForRequest(
    List<Map<String, dynamic>> payloads, {
    int limit = historyLimit,
  }) {
    if (payloads.length <= limit) return payloads;
    return payloads.sublist(payloads.length - limit);
  }

  /// Drops images from all but the last [keepLast] image-bearing messages
  /// (older photo turns become text-only). Photos would otherwise be
  /// re-read — and re-billed as vision tokens — on every later reply.
  /// Pure so the rule is unit-testable.
  @visibleForTesting
  static List<Map<String, dynamic>> stripStaleImages(
    List<Map<String, dynamic>> payloads, {
    int keepLast = 2,
  }) {
    var seen = 0;
    var changed = false;
    final out = <Map<String, dynamic>>[];
    for (var i = payloads.length - 1; i >= 0; i--) {
      final payload = payloads[i];
      final content = payload['content'];
      final blocks = content is List ? content : const [];
      final hasImages = blocks.any(
        (b) => b is Map && b['type'] == 'image_url',
      );
      if (!hasImages) {
        out.add(payload);
        continue;
      }
      seen++;
      if (seen <= keepLast) {
        out.add(payload);
        continue;
      }
      final text = blocks
          .whereType<Map>()
          .where((b) => b['type'] == 'text' && b['text'] is String)
          .map((b) => b['text'] as String)
          .join('\n');
      changed = true;
      out.add({'role': payload['role'], 'content': text});
    }
    if (!changed) return payloads;
    return out.reversed.toList();
  }

  /// Pulls tappable web sources out of this turn's tool results so they
  /// can ride on the finished assistant message (and survive reloads).
  /// Dedups by URL, caps at 5. Pure so the rule is unit-testable.
  static List<Map<String, String>> webSourcesFromToolResults(
    List<Map<String, dynamic>> toolResults,
  ) {
    final seen = <String>{};
    final out = <Map<String, String>>[];
    void add(String title, String url, String site) {
      final u = url.trim();
      if (u.isEmpty || !u.startsWith('http') || !seen.add(u)) return;
      if (out.length >= 5) return;
      out.add({'title': title.trim(), 'url': u, 'site': site.trim()});
    }

    for (final r in toolResults) {
      if (r['tool'] == 'web_search') {
        final results = r['results'];
        if (results is List) {
          for (final s in results) {
            if (s is Map) {
              add('${s['title'] ?? ''}', '${s['url'] ?? ''}', '${s['site'] ?? ''}');
            }
          }
        }
      } else if (r['tool'] == 'read_web_page') {
        final pages = r['pages'];
        if (pages is List) {
          for (final p in pages) {
            if (p is Map) {
              final url = '${p['url'] ?? ''}';
              add('${p['title'] ?? ''}', url, _hostOf(url));
            }
          }
        }
      } else if (r['tool'] == 'browse_web' && r['status'] == 'COMPLETED') {
        // Browsed pages carry a single url+title (RUNNING polls are skipped
        // — the COMPLETED result in the same turn holds the source).
        final url = '${r['url'] ?? ''}';
        add('${r['title'] ?? ''}', url, _hostOf(url));
      }
    }
    return out;
  }

  static String _hostOf(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return '';
    }
  }

  /// True when a streamed `tool_status` names a real tool call, as opposed
  /// to a phase marker (`generating`, `executing`, `round_1_done`, ...).
  /// Pure so the rule is unit-testable.
  @visibleForTesting
  static bool isToolActionStatus(String status) {
    if (status.isEmpty || status.contains(':')) return false;
    switch (status) {
      case 'generating':
      case 'thinking':
      case 'executing':
      case 'repairing':
      case 'done':
        return false;
    }
    if (status.startsWith('round_')) return false;
    return true;
  }

  void _trackToolStarted(String status) {
    if (!isToolActionStatus(status)) {
      if (status == 'done' && _activeTools.isNotEmpty) {
        _activeTools = [];
        activeToolsNotifier.value = const [];
      }
      return;
    }
    if (_activeTools.contains(status)) return;
    _activeTools = [..._activeTools, status];
    activeToolsNotifier.value = List.unmodifiable(_activeTools);
  }

  void _trackToolFinished(String tool) {
    if (!_activeTools.contains(tool)) return;
    _activeTools = _activeTools.where((t) => t != tool).toList();
    activeToolsNotifier.value = List.unmodifiable(_activeTools);
  }

  void _resetDraftState() {
    _draftResponse = '';
    _draftReasoning = '';
    _activeTools = [];
    draftResponseNotifier.value = '';
    draftReasoningNotifier.value = '';
    activeToolsNotifier.value = const [];
    _toolResults = [];
    toolResultsNotifier.value = [];
    draftRevisionNotifier.value++;
  }

  @override
  void dispose() {
    draftRevisionNotifier.dispose();
    draftResponseNotifier.dispose();
    draftReasoningNotifier.dispose();
    activeToolsNotifier.dispose();
    toolResultsNotifier.dispose();
    super.dispose();
  }

  // ─── Core: Send a message to the AI ────────────────────────────

  Future<String> sendMessage({
    required String feature,
    required String message,
    String? contextOverride,
    bool stream = false,
    bool? enableThinking,
    String? callerName, // 'khentsgdz' or 'clairjassen'
    void Function(String toolStatus)? onToolStatus,
    void Function(Map<String, dynamic> result)? onToolResult,
    List<String> imageUrls = const [],
    // Canvas toggle from the chat bar. When false the server must not
    // create any interactive artifacts — plain text only, even for quizzes.
    bool canvasEnabled = true,
  }) async {
    _isLoading = true;
    _activeRequest++;
    final myRequest = _activeRequest;
    _lastError = null;
    _resetDraftState();

    AIConversation? conversation;

    // Determine who's chatting
    final caller = callerName ?? _auth.currentUser?.uid ?? 'unknown';

    try {
      conversation = await _getOrCreateConversation(feature);

      // Add user message BEFORE notifying so the UI shows it immediately
      conversation.messages.add(
        AIMessage(role: 'user', content: message, imageUrls: imageUrls),
      );
      _setConversation(feature, conversation);
      notifyListeners();

      // Gather context: if contextOverride is set, use it directly.
      // Otherwise, pass feature + caller to the server so it builds context
      // server-side (Firestore reads from GCP region are near-instant).
      final context =
          contextOverride ?? ''; // server builds from feature+caller

      // Load permanent memories (trimmed for the tiny mascot).
      await _ensureMemoriesLoaded();
      final memoriesForRequest = feature == 'guardian' && _memoryRepo.all.length > 10
          ? _memoryRepo.all.sublist(0, 10)
          : _memoryRepo.all;

      // Build the API messages payload (recent history only — older turns
      // live on in archived sessions + summaries server-side).
      final isGuardian = feature == 'guardian';
      final allPayloads = conversation.messages
          .map((m) => m.toApiPayload())
          .toList();
      final recentMessages = stripStaleImages(
        trimHistoryForRequest(
          allPayloads,
          limit: isGuardian ? guardianHistoryLimit : historyLimit,
        ),
      );

      final shouldThink =
          enableThinking ?? const MotchiQuality().shouldAutoThink(message);
      // Big artifact builds (games, quizzes) stream far longer than chat —
      // give them a roomier timeout so a slow generation still lands its
      // closing fence (no fence = no Preview button).
      final artifactExpected = motchiWantsArtifact(message);

      String reply;
      var webSources = <Map<String, String>>[];

      if (stream) {
        // ── Streaming mode ─────────────────────────────
        reply = await _callProxyAIStream(
          recentMessages,
          context,
          memoriesForRequest,
          feature,
          caller,
          (chunk) {
            if (myRequest != _activeRequest) return;
            _draftResponse += chunk;
            draftResponseNotifier.value = _draftResponse;
            draftRevisionNotifier.value++;
          },
          onReasoning: (reasoning) {
            if (myRequest != _activeRequest) return;
            _draftReasoning += reasoning;
            draftReasoningNotifier.value = _draftReasoning;
            draftRevisionNotifier.value++;
          },
          onToolStatus: (status) {
            if (myRequest != _activeRequest) return;
            _trackToolStarted(status);
            draftRevisionNotifier.value++;
          },
          onToolResult: (result) {
            if (myRequest != _activeRequest) return;
            _toolResults.add(result);
            final tool = result['tool'];
            if (tool is String && tool.isNotEmpty) _trackToolFinished(tool);
            toolResultsNotifier.value = List.from(_toolResults);
            draftRevisionNotifier.value++;
          },
          onError: (error) {
            if (myRequest != _activeRequest) return;
            _lastError = error;
            _resetDraftState();
            notifyListeners();
          },
          enableThinking: shouldThink,
          canvasEnabled: canvasEnabled,
          artifactExpected: artifactExpected,
        );
        // Superseded by cancelCurrentReply() or a newer request: that path
        // already published its own state, so leave it untouched.
        if (myRequest != _activeRequest) return reply;
        // Keep web sources before the draft state (and tool results)
        // is cleared — they persist on the finished reply below.
        webSources = webSourcesFromToolResults(_toolResults);
        _resetDraftState();
      } else {
        // ── Non-streaming mode ─────────────────────────
        reply = await _callProxyAI(
          recentMessages,
          context,
          memoriesForRequest,
          feature,
          caller,
          canvasEnabled,
          shouldThink,
        );
      }

      // An empty reply means the stream was cut before any text arrived
      // (server timeout mid-tool-round, truncated generation). Surfacing
      // an error with Retry beats silent no-reply — Clair should never
      // stare at her own message wondering if Motchi heard her.
      if (reply.trim().isEmpty) {
        throw Exception(
          'Motchi got distracted and lost her train of thought. Try asking again?',
        );
      }
      // Strip the model's leading blank lines/whitespace so the reply
      // starts right at the first real line instead of a visible gap.
      final cleaned = reply.trimLeft();
      conversation.messages.add(
        AIMessage(role: 'assistant', content: cleaned, sources: webSources),
      );

      // Publish the finished reply to the UI immediately so the loading
      // state ends as soon as the stream does; Firestore writes below can
      // take seconds and must not hold the chat in "thinking".
      _isLoading = false;
      _lastError = null;
      _resetDraftState();
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

      // W1-C10: Memory extraction now handled server-side (functions/index.js
      // serverExtractAndSaveMemory) to avoid an extra client LLM round-trip.
      // Client-side extraction disabled for latency/cost saving.

      return reply;
    } catch (e) {
      // A superseded request must not clobber the newer request's state.
      if (myRequest != _activeRequest) return '';
      _isLoading = false;
      _resetDraftState();
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

  /// Stops the in-flight assistant reply (user-pressed Stop).
  ///
  /// Keeps the optimistic user message and persists whatever partial text
  /// has streamed so far. Late stream callbacks from the abandoned request
  /// are ignored via [_activeRequest]. Returns false when nothing is running.
  bool cancelCurrentReply() {
    if (!_isLoading || _activeRequest == 0) return false;
    _activeRequest = 0;
    final conv = _conversationRepo.assistant;
    final partial = _draftResponse.trimLeft();
    if (conv != null && partial.isNotEmpty) {
      conv.messages.add(AIMessage(role: 'assistant', content: partial));
      if (conv.messages.length > 50) {
        conv.messages.removeRange(0, conv.messages.length - 50);
      }
      _setConversation('assistant', conv);
      unawaited(_saveConversation(conv));
    }
    _isLoading = false;
    _lastError = null;
    _resetDraftState();
    notifyListeners();
    return true;
  }

  /// Send a message without persisting to conversation history (for one-shot queries).
  Future<String> quickAsk({
    required String message,
    String? context,
    String systemPrompt =
        'You are the Everglow AI — a helpful, loving assistant for Khent and Clair. Be warm, insightful, and concise.',
    bool includeMemories = true,
  }) async {
    try {
      final contextData = context ?? '';
      final systemMsg = contextData.isNotEmpty
          ? '$systemPrompt\n\nContext:\n$contextData'
          : systemPrompt;

      final messages = [
        {'role': 'user', 'content': message},
      ];

      final List<String> memories;
      if (includeMemories) {
        await _ensureMemoriesLoaded();
        memories = _memoryRepo.all;
      } else {
        memories = const [];
      }

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
          'memories': memories,
        }),
      ).timeout(const Duration(seconds: 30));

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

  // ─── Study Mode (Notebook-style, session-only) ─────────────────

  /// Streams one grounded answer for the Study screen.
  ///
  /// Unlike [sendMessage], nothing is persisted: no Firestore write, no
  /// memory extraction, no conversation thread. [history] holds prior
  /// display-only turns (question + answer text, never source material);
  /// [sourcesBlock] is prepended to [question] so the model answers from
  /// the attached PDFs only. Reuses the draft notifiers so the Study
  /// screen streams exactly like Motchi chat.
  Future<String> streamStudyReply({
    required List<Map<String, String>> history,
    required String sourcesBlock,
    required String question,
    String? callerName,
    bool enableThinking = true,
    bool canvasEnabled = true,
  }) async {
    _isLoading = true;
    _lastError = null;
    _resetDraftState();
    notifyListeners();

    final caller = callerName ?? _auth.currentUser?.uid ?? 'unknown';
    try {
      final messages = <Map<String, dynamic>>[
        for (final turn in history)
          {'role': turn['role'], 'content': turn['content']},
        {
          'role': 'user',
          'content': '$sourcesBlock\n\n$question',
        },
      ];

      final reply = await _callProxyAIStream(
        messages,
        '',
        const [],
        'study',
        caller,
        (chunk) {
          _draftResponse += chunk;
          draftResponseNotifier.value = _draftResponse;
          draftRevisionNotifier.value++;
        },
        onReasoning: (reasoning) {
          _draftReasoning += reasoning;
          draftReasoningNotifier.value = _draftReasoning;
          draftRevisionNotifier.value++;
        },
        onToolStatus: (status) {
          _trackToolStarted(status);
          draftRevisionNotifier.value++;
        },
        onToolResult: (result) {
          _toolResults.add(result);
          final tool = result['tool'];
          if (tool is String && tool.isNotEmpty) _trackToolFinished(tool);
          toolResultsNotifier.value = List.from(_toolResults);
          draftRevisionNotifier.value++;
        },
        onError: (error) {
          _lastError = error;
          notifyListeners();
        },
        enableThinking: enableThinking,
        canvasEnabled: canvasEnabled,
        artifactExpected: motchiWantsArtifact(question),
      );

      _isLoading = false;
      _resetDraftState();
      notifyListeners();
      return reply;
    } catch (e) {
      _isLoading = false;
      _lastError = e.toString();
      _resetDraftState();
      notifyListeners();
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
      // Thinking mode off: mascot replies should be instant, not deep reasoned.
      enableThinking: false,
      contextOverride:
          'You are Motchi 🍡 — the magical white cat who lives inside Everglow and watches over Khent and Clair. Your Guardian form appears as a cute floating cat on the dashboard. Speak in warm, playful, expressive messages. You can be 1-4 sentences depending on what feels right. Use emojis sometimes. Be genuinely helpful — answer questions, give suggestions, check in on how they\'re doing.',
    );
  }

  // ─── Permanent Memory System ───────────────────────────────────

  Future<void> _ensureMemoriesLoaded() => _memoryRepo.load();

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

  /// Motchi writes a note to the Starlight Jar.
  Future<void> writeStarlightNote(String content, {String? author}) async {
    try {
      final db = FirebaseFirestore.instance;
      final uid = author ?? _auth.currentUser?.uid ?? 'motchi';
      final username = uid == 'khentsgdz'
          ? 'khentsgdz'
          : uid == 'clairjassen'
          ? 'clairjassen'
          : 'motchi';
      await db.collection('starlight_jar').add({
        'content': content,
        'author': username,
        'timestamp': FieldValue.serverTimestamp(),
        'writtenBy': 'Motchi 🍡',
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
    List<String> memories, [
    String feature = '',
    String caller = '',
    bool canvasEnabled = true,
    bool enableThinking = true,
  ]) async {
    const maxRetries = 2;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await _callProxyAIOnce(
          messages,
          context,
          memories,
          feature,
          caller,
          canvasEnabled,
          enableThinking,
        );
      } catch (e) {
        final isTransient =
            e is SocketException ||
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
    List<String> memories, [
    String feature = '',
    String caller = '',
    bool canvasEnabled = true,
    bool enableThinking = true,
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
            'enableThinking': enableThinking,
            'canvas': canvasEnabled,
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
    void Function(Map<String, dynamic> result)? onToolResult,
    void Function(String error)? onError,
    bool enableThinking = true,
    bool canvasEnabled = true,
    bool artifactExpected = false,
  }) async {
    const maxRetries = 2;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) _lastError = null;
        return await _callProxyAIStreamOnce(
          messages,
          context,
          memories,
          feature,
          caller,
          onChunk,
          onReasoning,
          onToolStatus,
          onToolResult,
          onError,
          enableThinking: enableThinking,
          canvasEnabled: canvasEnabled,
          artifactExpected: artifactExpected,
        );
      } catch (e) {
        final isTransient =
            e is SocketException ||
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
    void Function(Map<String, dynamic> result)? onToolResult,
    void Function(String error)? onError, {
    bool enableThinking = true,
    bool canvasEnabled = true,
    bool artifactExpected = false,
  }) async {
    final idToken = await _auth.currentUser?.getIdToken() ?? '';
    final body = jsonEncode({
      'messages': messages,
      'context': context,
      'memories': memories,
      'feature': feature,
      'caller': caller,
      'stream': true, // enables real SSE streaming from the backend
      'enableThinking': enableThinking,
      'canvas': canvasEnabled,
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
      onToolResult: onToolResult,
      onError: onError,
      // Artifact builds and thinking requests get 280s (inside the server's
      // 300s function budget) so slow generations or multi-turn tool loops
      // land cleanly. Everyday chat keeps 180s.
      timeout: (artifactExpected || enableThinking)
          ? const Duration(seconds: 280)
          : const Duration(seconds: 180),
    );
  }

  // Firestore Persistence

  Future<AIConversation> _getOrCreateConversation(String feature) =>
      _conversationRepo.getOrCreate(feature);

  Future<void> _saveConversation(AIConversation conversation) =>
      _conversationRepo.save(conversation);

  void _setConversation(String feature, AIConversation? conv) =>
      _conversationRepo.setConversation(feature, conv);

  Future<void> clearConversation(String feature, {bool archive = true}) async {
    await _conversationRepo.clear(feature, archive: archive);
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

  // ─── Session Management ─────────────────────────────────────────

  /// List all archived sessions, newest first.
  Future<List<AISession>> listSessions({int limit = 50}) =>
      _conversationRepo.listSessions(limit: limit);

  /// Realtime stream of archived sessions, newest first.
  ///
  /// Powers the sidebar's auto-refresh: any archive or delete pushes a
  /// fresh list without a manual reload.
  Stream<List<AISession>> watchSessions({int limit = 50}) =>
      _conversationRepo.watchSessions(limit: limit);

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
  Future<void> deleteSession(String sessionId) async {
    await _conversationRepo.deleteSession(sessionId);
    notifyListeners();
  }

  /// Archive the current conversation as a new session.
  Future<void> archiveCurrentSession() async {
    final conv = _conversationRepo.assistant;
    if (conv != null && conv.messages.length >= 2) {
      await _conversationRepo.archiveSession(conv);
    }
  }
}
