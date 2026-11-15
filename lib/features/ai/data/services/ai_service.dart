import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/ai_conversation.dart';
import '../../domain/motchi_quality.dart';
import '../../domain/motchi_reply_details.dart';
import '../../../../core/agent/agent_mode.dart';
import 'ai_memory_repo.dart';
import 'ai_conversation_repo.dart';
import '../../domain/repositories/ai_memory_repo_interface.dart';
import '../../domain/repositories/ai_conversation_repo_interface.dart';
import 'sse_streamer.dart';
import 'sse_cancellation.dart';
import 'study_artifact.dart';

class AIService extends ChangeNotifier {
  final IAIMemoryRepository _memoryRepo;
  final IAIConversationRepository _conversationRepo;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  AIService({
    IAIMemoryRepository? memoryRepo,
    IAIConversationRepository? conversationRepo,
  }) : _memoryRepo = memoryRepo ?? AIMemoryRepository(),
       _conversationRepo = conversationRepo ?? AIConversationRepository();

  List<String> get memories => _memoryRepo.all;
  AIConversation? get assistantConversation => _conversationRepo.assistant;
  AIConversation? get guardianConversation => _conversationRepo.guardian;

  String? _currentSessionId;
  String get currentSessionId => _currentSessionId ??= _generateSessionId();

  String _generateSessionId() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final rand = (math.Random().nextInt(900000) + 100000).toString();
    return 'sess_${stamp}_$rand';
  }

  bool _isLoading = false;
  bool _isNavigating = false;
  int _activeRequest = 0;
  String? _actionScopeId;
  String? get currentActionScopeId => _actionScopeId;
  SseCancellation? _streamCancellation;
  String? _lastError;
  String _draftResponse = '';
  String _draftReasoning = '';
  List<String> _activeTools = [];

  final ValueNotifier<int> draftRevisionNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> draftResponseNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> draftReasoningNotifier = ValueNotifier<String>(
    '',
  );
  final ValueNotifier<List<String>> activeToolsNotifier =
      ValueNotifier<List<String>>(const []);
  final ValueNotifier<List<Map<String, dynamic>>> toolResultsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  List<Map<String, dynamic>> _toolResults = [];
  List<Map<String, dynamic>> get toolResults => List.unmodifiable(_toolResults);
  List<String> get activeTools => List.unmodifiable(_activeTools);

  bool get isLoading => _isLoading;
  bool get isNavigating => _isNavigating;
  String? get lastError => _lastError;
  String get draftResponse => _draftResponse;
  String get draftReasoning => _draftReasoning;

  static const int historyLimit = 20;

  static const int guardianHistoryLimit = 12;

  @visibleForTesting
  static List<Map<String, dynamic>> trimHistoryForRequest(
    List<Map<String, dynamic>> payloads, {
    int limit = historyLimit,
  }) {
    if (payloads.length <= limit) return payloads;
    return payloads.sublist(payloads.length - limit);
  }

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
      final hasImages = blocks.any((b) => b is Map && b['type'] == 'image_url');
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
              add(
                '${s['title'] ?? ''}',
                '${s['url'] ?? ''}',
                '${s['site'] ?? ''}',
              );
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
    _streamCancellation?.cancel();
    draftRevisionNotifier.dispose();
    draftResponseNotifier.dispose();
    draftReasoningNotifier.dispose();
    activeToolsNotifier.dispose();
    toolResultsNotifier.dispose();
    super.dispose();
  }

  Future<String> sendMessage({
    required String feature,
    required String message,
    String? contextOverride,
    bool stream = false,
    bool? enableThinking,
    String? callerName,
    void Function(String toolStatus)? onToolStatus,
    void Function(Map<String, dynamic> result)? onToolResult,
    List<String> imageUrls = const [],
    bool canvasEnabled = true,
    String? actionScopeId,
  }) async {
    if (_isNavigating) {
      throw StateError('Wait for the conversation to finish opening.');
    }
    _isLoading = true;
    _activeRequest++;
    final previous = _conversationRepo.assistant?.messages.lastOrNull;
    _actionScopeId =
        actionScopeId ??
        (RegExp(
              r'^(yes|yep|okay|ok|sure|continue|finish|retry|try again)[.!?\s]*$',
              caseSensitive: false,
            ).hasMatch(message.trim())
            ? previous?.actionScopeId
            : null) ??
        _generateSessionId();
    final myRequest = _activeRequest;
    _lastError = null;
    _resetDraftState();

    AIConversation? conversation;

    final caller = callerName ?? _auth.currentUser?.uid ?? 'unknown';

    try {
      conversation = await _getOrCreateConversation(feature);

      conversation.messages.add(
        AIMessage(
          role: 'user',
          content: message,
          imageUrls: imageUrls,
          actionScopeId: _actionScopeId,
        ),
      );
      _setConversation(feature, conversation);
      notifyListeners();

      final context =
          contextOverride ?? '';

      const memoriesForRequest = <String>[];

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
      final artifactExpected = motchiWantsArtifact(message);

      String reply;
      var webSources = <Map<String, String>>[];
      var details = const MotchiReplyDetails();

      if (stream) {
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
            notifyListeners();
          },
          enableThinking: shouldThink,
          canvasEnabled: canvasEnabled,
          artifactExpected: artifactExpected,
        );
        if (myRequest != _activeRequest) return reply;
        webSources = webSourcesFromToolResults(_toolResults);
        details = MotchiReplyDetails.fromResults(_toolResults);
      } else {
        reply = await _callProxyAI(
          recentMessages,
          context,
          memoriesForRequest,
          feature,
          caller,
          canvasEnabled,
          shouldThink,
          (data) => details = MotchiReplyDetails.fromJson(data),
        );
        if (myRequest != _activeRequest) {
          return MotchiReplyDetails.visibleText(reply);
        }
      }

      if (reply.trim().isEmpty && !details.isEmpty) reply = details.summary;
      if (reply.trim().isEmpty) {
        throw Exception(
          'Motchi got distracted and lost her train of thought. Try asking again?',
        );
      }
      final cleaned = MotchiReplyDetails.visibleText(reply).trimLeft();
      conversation.messages.add(
        AIMessage(
          role: 'assistant',
          content: cleaned,
          sources: webSources,
          details: details,
          actionScopeId: _actionScopeId,
        ),
      );

      _isLoading = false;
      _lastError = null;
      _resetDraftState();
      _setConversation(feature, conversation);
      notifyListeners();

      if (conversation.messages.length > 50) {
        conversation.messages.removeRange(0, conversation.messages.length - 50);
      }
      await _saveConversation(conversation);

      if (conversation.messages.length >= 4 &&
          conversation.messages.length % 20 <= 1) {
        try {
          await _archiveSession(conversation);
        } catch (e) {
          debugPrint('[AIService] Session archive failed: $e');
        }
      }

      return cleaned;
    } catch (e) {
      if (myRequest != _activeRequest) return '';
      _isLoading = false;
      final details = MotchiReplyDetails.fromResults(
        _toolResults,
        interrupted: true,
        activeTools: _activeTools,
      );
      if (conversation != null &&
          (details.steps.isNotEmpty || _draftResponse.isNotEmpty)) {
        conversation.messages.add(
          AIMessage(
            role: 'assistant',
            content:
                MotchiReplyDetails.visibleText(_draftResponse).trim().isEmpty
                ? details.summary
                : MotchiReplyDetails.visibleText(_draftResponse),
            details: details,
            actionScopeId: _actionScopeId,
          ),
        );
        _setConversation(feature, conversation);
        unawaited(_saveConversation(conversation));
      }
      _resetDraftState();
      _lastError = e.toString();
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

  bool cancelCurrentReply() {
    if (!_isLoading || _activeRequest == 0) return false;
    _activeRequest++;
    _streamCancellation?.cancel();
    final conv = _conversationRepo.assistant;
    final partial = MotchiReplyDetails.visibleText(_draftResponse).trimLeft();
    final details = MotchiReplyDetails.fromResults(
      _toolResults,
      interrupted: true,
      activeTools: _activeTools,
    );
    if (conv != null && (partial.isNotEmpty || details.steps.isNotEmpty)) {
      conv.messages.add(
        AIMessage(
          role: 'assistant',
          content: partial.isEmpty ? details.summary : partial,
          details: details,
          actionScopeId: _actionScopeId,
        ),
      );
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

      final idToken = await _auth.currentUser?.getIdToken() ?? '';

      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'systemPrompt': systemMsg,
              'messages': messages,
              'context': contextData,
              'includeMemories': includeMemories,
            }),
          )
          .timeout(const Duration(seconds: 30));

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
        {'role': 'user', 'content': '$sourcesBlock\n\n$question'},
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

  Future<AIMessage> sendTemporaryMessage({
    required String message,
    required List<AIMessage> history,
    String? callerName,
    bool? enableThinking,
    bool canvasEnabled = true,
    List<String> imageUrls = const [],
    String? sessionId,
    String? contextOverride,
  }) async {
    _isLoading = true;
    _activeRequest++;
    final myRequest = _activeRequest;
    _lastError = null;
    _resetDraftState();
    notifyListeners();

    final caller = callerName ?? _auth.currentUser?.uid ?? 'unknown';

    try {
      final userMessage = AIMessage(
        role: 'user',
        content: message,
        imageUrls: imageUrls,
      );
      final allMessages = [...history, userMessage];
      final allPayloads = allMessages.map((m) => m.toApiPayload()).toList();
      final recentMessages = stripStaleImages(
        trimHistoryForRequest(allPayloads, limit: historyLimit),
      );

      final shouldThink =
          enableThinking ?? const MotchiQuality().shouldAutoThink(message);
      final artifactExpected = motchiWantsArtifact(message);
      final effectiveSessionId =
          sessionId ?? 'temp_anime_${DateTime.now().millisecondsSinceEpoch}';

      var reply = await _callProxyAIStream(
        recentMessages,
        contextOverride ?? '',
        const [],
        'assistant',
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
          notifyListeners();
        },
        enableThinking: shouldThink,
        canvasEnabled: canvasEnabled,
        artifactExpected: artifactExpected,
        sessionIdOverride: effectiveSessionId,
        temporary: true,
      );

      if (myRequest != _activeRequest) {
        return AIMessage(
          role: 'assistant',
          content: MotchiReplyDetails.visibleText(reply),
        );
      }

      final webSources = webSourcesFromToolResults(_toolResults);
      var details = MotchiReplyDetails.fromResults(_toolResults);

      if (reply.trim().isEmpty && !details.isEmpty) {
        reply = details.summary;
      }
      if (reply.trim().isEmpty) {
        throw Exception(
          'Motchi got distracted and lost her train of thought. Try asking again?',
        );
      }

      final cleaned = MotchiReplyDetails.visibleText(reply).trimLeft();

      _isLoading = false;
      _lastError = null;
      _resetDraftState();
      notifyListeners();

      return AIMessage(
        role: 'assistant',
        content: cleaned,
        sources: webSources,
        details: details,
      );
    } catch (e) {
      if (myRequest != _activeRequest) {
        return AIMessage(role: 'assistant', content: '');
      }
      _isLoading = false;
      _lastError = e.toString();
      _resetDraftState();
      notifyListeners();
      rethrow;
    }
  }

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
      enableThinking: false,
      contextOverride:
          'You are Motchi 🍡 — the magical white cat who lives inside Everglow and watches over Khent and Clair. Your Guardian form appears as a cute floating cat on the dashboard. Speak in warm, playful, expressive messages. You can be 1-4 sentences depending on what feels right. Use emojis sometimes. Be genuinely helpful — answer questions, give suggestions, check in on how they\'re doing.',
    );
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

  String get _cloudFunctionUrl {
    if (kIsWeb) {
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
    void Function(Map<String, dynamic>)? onDetails,
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
          onDetails,
        );
      } catch (e) {
        final isTransient =
            e is SocketException ||
            e is TimeoutException ||
            (e is Exception && e.toString().contains('503')) ||
            (e is Exception && e.toString().contains('502')) ||
            (e is Exception && e.toString().contains('429'));
        if (attempt < maxRetries && isTransient && feature != 'assistant') {
          await Future.delayed(Duration(seconds: 1 << attempt));
          continue;
        }
        rethrow;
      }
    }
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
    void Function(Map<String, dynamic>)? onDetails,
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
            if (memories.isNotEmpty) 'memories': memories,
            if (feature.isNotEmpty) 'feature': feature,
            if (caller.isNotEmpty) 'caller': caller,
            'sessionId': currentSessionId,
            if (_actionScopeId != null) 'actionScopeId': _actionScopeId,
            'enableThinking': enableThinking,
            'canvas': canvasEnabled,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['details'] is Map) {
        onDetails?.call(Map<String, dynamic>.from(data['details'] as Map));
      }
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
    String? sessionIdOverride,
    bool temporary = false,
  }) async {
    const maxRetries = 2;
    var receivedEvent = false;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) _lastError = null;
        return await _callProxyAIStreamOnce(
          messages,
          context,
          memories,
          feature,
          caller,
          (chunk) {
            receivedEvent = true;
            onChunk(chunk);
          },
          (chunk) {
            receivedEvent = true;
            onReasoning?.call(chunk);
          },
          (status) {
            receivedEvent = true;
            onToolStatus?.call(status);
          },
          (result) {
            receivedEvent = true;
            onToolResult?.call(result);
          },
          onError,
          enableThinking: enableThinking,
          canvasEnabled: canvasEnabled,
          artifactExpected: artifactExpected,
          sessionIdOverride: sessionIdOverride,
          temporary: temporary,
        );
      } catch (e) {
        final isTransient =
            e is SocketException ||
            e is TimeoutException ||
            (e is Exception && e.toString().contains('503')) ||
            (e is Exception && e.toString().contains('502')) ||
            (e is Exception && e.toString().contains('429'));
        if (attempt < maxRetries &&
            isTransient &&
            !receivedEvent &&
            feature != 'assistant') {
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
    String? sessionIdOverride,
    bool temporary = false,
  }) async {
    final idToken = await _auth.currentUser?.getIdToken() ?? '';
    final body = jsonEncode({
      'messages': messages,
      'context': context,
      if (memories.isNotEmpty) 'memories': memories,
      'feature': feature,
      'caller': caller,
      'sessionId': sessionIdOverride ?? currentSessionId,
      if (!temporary && _actionScopeId != null) 'actionScopeId': _actionScopeId,
      if (temporary) 'temporary': true,
      'stream': true,
      'enableThinking': enableThinking,
      'canvas': canvasEnabled,
    });

    final cancellation = SseCancellation();
    _streamCancellation = cancellation;
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
      cancellation: cancellation,
      timeout: artifactExpected
          ? const Duration(seconds: 285)
          : enableThinking
          ? const Duration(seconds: 185)
          : const Duration(seconds: 95),
    );
  }

  final Map<String, Map<String, dynamic>> _demoCompanions = {};

  Future<Map<String, dynamic>> companionOperation(
    String operation, {
    Map<String, dynamic>? value,
  }) async {
    if (AgentMode.isActive.value) {
      final demo = _demoCompanions.putIfAbsent(
        AgentMode.activeProfile.value,
        () => {
          'preferences': {
            'nudges': 'daily',
            'digests': true,
            'quietStart': 22,
            'quietEnd': 8,
          },
          'feedback': <Map<String, dynamic>>[],
        },
      );
      if (operation == 'preferences') demo['preferences'] = value;
      if (operation == 'feedback') {
        final feedback = demo['feedback'] as List<Map<String, dynamic>>;
        feedback.add({...?value});
        if (feedback.length > 20) feedback.removeAt(0);
      }
      return demo;
    }
    final token = await _auth.currentUser?.getIdToken() ?? '';
    final response = await http
        .post(
          Uri.parse(_cloudFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'companionOperation': operation, 'value': ?value}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Could not save your Motchi preferences. Try again.');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<AIConversation> _getOrCreateConversation(String feature) =>
      _conversationRepo.getOrCreate(feature);

  Future<void> _saveConversation(AIConversation conversation) =>
      _conversationRepo.save(conversation);

  void _setConversation(String feature, AIConversation? conv) =>
      _conversationRepo.setConversation(feature, conv);

  Future<void> clearConversation(String feature, {bool archive = true}) async {
    if (_isLoading || _isNavigating) {
      throw StateError('Wait for the current chat action to finish.');
    }
    _isNavigating = true;
    notifyListeners();
    try {
      await _conversationRepo.clear(feature, archive: archive);
      _currentSessionId = null;
    } finally {
      _isNavigating = false;
      notifyListeners();
    }
  }

  Future<void> loadAssistantConversation() async {
    await _conversationRepo.loadAssistant();
    notifyListeners();
  }

  void startFreshSession() {
    _currentSessionId = null;
    _conversationRepo.startFresh();
    notifyListeners();
  }

  Future<void> _archiveSession(AIConversation conversation) =>
      _conversationRepo.archiveSession(conversation);

  Future<List<AISession>> listSessions({int limit = 50}) =>
      _conversationRepo.listSessions(limit: limit);

  Stream<List<AISession>> watchSessions({int limit = 50}) =>
      _conversationRepo.watchSessions(limit: limit);

  Future<void> switchSession(String sessionId) async {
    if (_isLoading || _isNavigating) {
      throw StateError('Wait for the current chat action to finish.');
    }
    _isNavigating = true;
    notifyListeners();
    try {
      await _conversationRepo.loadSession(sessionId);
      _currentSessionId = sessionId;
      final conv = _conversationRepo.assistant;
      if (conv != null) {
        await _conversationRepo.save(conv);
      }
    } finally {
      _isNavigating = false;
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    await _conversationRepo.deleteSession(sessionId);
    notifyListeners();
  }

  Future<void> archiveCurrentSession() async {
    final conv = _conversationRepo.assistant;
    if (conv != null && conv.messages.length >= 2) {
      await _conversationRepo.archiveSession(conv);
    }
  }
}
