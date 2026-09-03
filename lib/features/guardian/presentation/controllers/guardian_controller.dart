import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/guardian_message.dart';
import '../../data/services/guardian_service.dart';
import '../../../heartbeat/data/services/mood_service.dart';
import '../../../heartbeat/data/models/user_mood.dart';
import '../../../../core/services/auth_service.dart';
import '../../../ai/data/services/ai_service.dart';
import '../../../../core/utils/logger.dart';

enum GuardianState { idle, greeting, reacting, thinking }

class GuardianController extends ChangeNotifier {
  final GuardianService _service;
  final MoodService? _moodService;
  final AuthService? _authService;
  final AIService? _aiService;
  final Random _random = Random();

  GuardianState _state = GuardianState.idle;
  GuardianMessage? _currentMessage;
  bool _isMessageVisible = false;
  bool _isMoodPromptVisible = false;
  bool _isAIMode = false;
  Timer? _idleTimer;
  Timer? _dismissTimer;
  int _messageCounter = 0;
  String? _lastUserMessage;
  DateTime? _lastTapAt;
  UserMood? _moodCache;
  DateTime? _moodCacheAt;
  DateTime? _lastAiGreetingAt;
  bool _idlePaused = false;

  static const _localGreetings = [
    '✨ Purring with love for you two!',
    '🐱 Meow! Hope today feels soft and sweet!',
    '🍡 Mochi is watching over you both!',
    '💕 You two make everything brighter!',
    '🌙 Rest a little — I saved you a warm spot!',
  ];

  GuardianController(
    this._service, {
    MoodService? moodService,
    AuthService? authService,
    AIService? aiService,
  }) : _moodService = moodService,
       _authService = authService,
       _aiService = aiService;

  GuardianState get state => _state;
  GuardianMessage? get currentMessage => _currentMessage;
  bool get isMessageVisible => _isMessageVisible;
  bool get isMoodPromptVisible => _isMoodPromptVisible;
  bool get isAIMode => _isAIMode;
  String? get lastUserMessage => _lastUserMessage;

  /// Toggle AI chat mode on/off.
  void toggleAIMode() {
    _isAIMode = !_isAIMode;
    if (_isAIMode) {
      // Show a greeting when AI mode turns on
      _currentMessage = GuardianMessage(
        id: 'ai_greeting',
        content: '✨ I\'m in AI mode now! Tap me and tell me something!',
        category: 'ai',
        createdAt: DateTime.now(),
      );
    } else {
      _currentMessage = GuardianMessage(
        id: 'mode_switch',
        content: 'Back to normal mode! 🐱',
        category: 'idle',
        createdAt: DateTime.now(),
      );
    }
    _isMessageVisible = true;
    notifyListeners();
    _scheduleDismiss(const Duration(seconds: 4));
  }

  /// Send a user message to the AI Guardian.
  Future<void> sendAIMessage(String message) async {
    if (_aiService == null) return;
    if (_state == GuardianState.thinking) return;

    _lastUserMessage = message;
    _state = GuardianState.thinking;
    _isMessageVisible = true;
    _dismissTimer?.cancel();
    _currentMessage = GuardianMessage(
      id: 'thinking',
      content: '🤔 *thinking...*',
      category: 'ai',
      createdAt: DateTime.now(),
    );
    notifyListeners();

    try {
      final reply = await _aiService.guardianChat(message);
      if (!mounted) return;

      _state = GuardianState.reacting;
      _currentMessage = GuardianMessage(
        id: 'ai_reply_${DateTime.now().millisecondsSinceEpoch}',
        content: reply,
        category: 'ai',
        createdAt: DateTime.now(),
      );
      _isMessageVisible = true;
      notifyListeners();
      _scheduleDismiss(const Duration(seconds: 8));
    } catch (e) {
      Logger.e('Guardian AI reply failed', error: e);
      if (!mounted) return;
      _state = GuardianState.idle;
      _currentMessage = GuardianMessage(
        id: 'error',
        content: '😿 Oops, I got distracted! Tap me again!',
        category: 'ai',
        createdAt: DateTime.now(),
      );
      _isMessageVisible = true;
      notifyListeners();
      _scheduleDismiss(const Duration(seconds: 4));
    }
  }

  /// Triggered on initial load.
  void welcome() {
    _state = GuardianState.greeting;
    notifyListeners();

    // Auto-idle after greeting animation duration
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _state = GuardianState.idle;
      _startIdleTimer();
      notifyListeners();
    });
  }

  /// Triggered on tap. Debounced so rapid taps don't spam reads/rebuilds.
  void react() {
    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastTapAt = now;
    _state = GuardianState.reacting;

    if (_isAIMode && _aiService != null) {
      // In AI mode, show a chat-like prompt instead of random message
      _dismissTimer?.cancel();
      _currentMessage = GuardianMessage(
        id: 'ai_prompt',
        content: '💬 Tell me something! What\'s on your mind?',
        category: 'ai',
        createdAt: DateTime.now(),
      );
      _isMessageVisible = true;
    } else {
      unawaited(_showMessage());
    }

    notifyListeners();

    // Reset to idle
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _state = GuardianState.idle;
      notifyListeners();
    });
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    if (_idlePaused) return;
    // Random interval 3-7 minutes
    final minutes = 3 + _random.nextInt(5);
    _idleTimer = Timer(Duration(minutes: minutes), () {
      if (!mounted || _idlePaused) return;
      // In AI mode, generate a contextual greeting
      if (_isAIMode && _aiService != null) {
        unawaited(_showAIGreeting());
      } else {
        unawaited(_showMessage());
      }
      _startIdleTimer(); // Loop
    });
  }

  /// Pause idle popups (e.g. app backgrounded or guardian offscreen).
  void pauseIdle() {
    _idlePaused = true;
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Resume idle popups.
  void resumeIdle() {
    if (!_idlePaused) return;
    _idlePaused = false;
    _startIdleTimer();
  }

  Future<void> _showAIGreeting() async {
    // Cheap path: reuse a local greeting most of the time, and never call
    // the AI more than once per 10 minutes for idle popups.
    final recentlyAsked = _lastAiGreetingAt != null &&
        DateTime.now().difference(_lastAiGreetingAt!) <
            const Duration(minutes: 10);
    final useLocal = recentlyAsked || _random.nextDouble() < 0.7;
    if (useLocal) {
      if (!mounted) return;
      _currentMessage = GuardianMessage(
        id: 'ai_greeting_${DateTime.now().millisecondsSinceEpoch}',
        content: _localGreetings[_random.nextInt(_localGreetings.length)],
        category: 'ai',
        createdAt: DateTime.now(),
      );
      _isMessageVisible = true;
      notifyListeners();
      _scheduleDismiss(const Duration(seconds: 6));
      return;
    }

    try {
      final greeting = await _aiService!.quickAsk(
        message:
            'Say a warm, playful greeting to the couple using the app. Be natural and varied — 1-2 sentences. Use an emoji.',
        systemPrompt:
            'You are Everglow Guardian — a cute magical cat mascot. Respond warmly with personality.',
        includeMemories: false,
      );
      _lastAiGreetingAt = DateTime.now();

      if (!mounted) return;
      _currentMessage = GuardianMessage(
        id: 'ai_greeting_${DateTime.now().millisecondsSinceEpoch}',
        content: greeting.isNotEmpty
            ? greeting
            : '✨ Purring with love for you two!',
        category: 'ai',
        createdAt: DateTime.now(),
      );
    } catch (_) {
      if (!mounted) return;
      // Fallback to static messages
      await _showMessage();
      return;
    }

    _isMessageVisible = true;
    notifyListeners();
    _scheduleDismiss(const Duration(seconds: 6));
  }

  Future<void> _showMessage() async {
    _messageCounter++;
    _dismissTimer?.cancel();

    // Occasionally mention partner's mood (every 5-10 messages).
    // Cached for 5 minutes and fetched with a one-shot get (no stream).
    if (_moodService != null &&
        _authService != null &&
        _messageCounter % 7 == 0) {
      try {
        final auth = _authService;
        final moodSvc = _moodService;
        final partnerUsername = auth.partnerUsername ?? '';
        final partnerName = auth.partnerName;

        UserMood? latestMood = _moodCache;
        final cacheFresh = _moodCacheAt != null &&
            DateTime.now().difference(_moodCacheAt!) <
                const Duration(minutes: 5);
        if (!cacheFresh && partnerUsername.isNotEmpty) {
          latestMood = await moodSvc
              .getLatestMood(partnerUsername)
              .timeout(const Duration(seconds: 6));
          _moodCache = latestMood;
          _moodCacheAt = DateTime.now();
        }

        if (latestMood != null && mounted) {
          _currentMessage = GuardianMessage(
            id: 'partner_mood',
            content: '$partnerName is feeling ${latestMood.moodEmoji} today!',
            category: 'mood',
            createdAt: DateTime.now(),
          );
          _isMessageVisible = true;
          notifyListeners();
          _scheduleDismiss(const Duration(seconds: 5));
          return;
        }
      } catch (e) {
        Logger.e('Guardian mood mention failed', error: e);
        // Fall through to a random message.
      }
    }

    _currentMessage = _service.getRandomMessage();
    if (_currentMessage != null && mounted) {
      _isMessageVisible = true;
      notifyListeners();
      _scheduleDismiss(const Duration(seconds: 5));
    }
  }

  void _scheduleDismiss(Duration after) {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(after, () {
      if (!mounted) return;
      // Don't hide a newer thinking/AI reply that arrived after scheduling.
      _isMessageVisible = false;
      if (_state != GuardianState.thinking) {
        _state = GuardianState.idle;
      }
      notifyListeners();
    });
  }

  void triggerMoodPrompt() {
    _dismissTimer?.cancel();
    _isMoodPromptVisible = true;
    _currentMessage = GuardianMessage(
      id: 'mood_prompt',
      content: 'How is your heart today?',
      category: 'prompt',
      createdAt: DateTime.now(),
    );
    _isMessageVisible = true;
    notifyListeners();
  }

  void dismissMoodPrompt() {
    _dismissTimer?.cancel();
    _isMoodPromptVisible = false;
    _isMessageVisible = false;
    notifyListeners();
  }

  bool _disposed = false;

  bool get mounted => !_disposed;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }
}
