import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/guardian_message.dart';
import '../../data/services/guardian_service.dart';
import '../../../heartbeat/data/services/mood_service.dart';
import '../../../heartbeat/data/models/user_mood.dart';
import '../../../../core/services/auth_service.dart';
import '../../../ai/data/services/ai_service.dart';

enum GuardianState { idle, greeting, reacting, thinking }

class GuardianController extends ChangeNotifier {
  final GuardianService _service;
  final MoodService? _moodService;
  final AuthService? _authService;
  AIService? _aiService;

  GuardianState _state = GuardianState.idle;
  GuardianMessage? _currentMessage;
  bool _isMessageVisible = false;
  bool _isMoodPromptVisible = false;
  bool _isAIMode = false;
  Timer? _idleTimer;
  int _messageCounter = 0;
  String? _lastUserMessage;

  GuardianController(this._service,
      {MoodService? moodService, AuthService? authService, AIService? aiService})
      : _moodService = moodService,
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

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _isMessageVisible = false;
        notifyListeners();
      }
    });
  }

  /// Send a user message to the AI Guardian.
  Future<void> sendAIMessage(String message) async {
    if (_aiService == null) return;
    if (_state == GuardianState.thinking) return;

    _lastUserMessage = message;
    _state = GuardianState.thinking;
    _isMessageVisible = true;
    _currentMessage = GuardianMessage(
      id: 'thinking',
      content: '🤔 *thinking...*',
      category: 'ai',
      createdAt: DateTime.now(),
    );
    notifyListeners();

    try {
      final reply = await _aiService!.guardianChat(message);
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

      // Auto-dismiss after 8 seconds
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) {
          _isMessageVisible = false;
          _state = GuardianState.idle;
          notifyListeners();
        }
      });
    } catch (e) {
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

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          _isMessageVisible = false;
          notifyListeners();
        }
      });
    }
  }

  /// Triggered on initial load.
  void welcome() {
    _state = GuardianState.greeting;
    notifyListeners();

    // Auto-idle after greeting animation duration
    Future.delayed(const Duration(seconds: 2), () {
      _state = GuardianState.idle;
      _startIdleTimer();
      notifyListeners();
    });
  }

  /// Triggered on tap.
  void react() {
    _state = GuardianState.reacting;

    if (_isAIMode && _aiService != null) {
      // In AI mode, show a chat-like prompt instead of random message
      _currentMessage = GuardianMessage(
        id: 'ai_prompt',
        content: '💬 Tell me something! What\'s on your mind?',
        category: 'ai',
        createdAt: DateTime.now(),
      );
      _isMessageVisible = true;
    } else {
      _showMessage();
    }

    notifyListeners();

    // Reset to idle
    Future.delayed(const Duration(milliseconds: 800), () {
      _state = GuardianState.idle;
      notifyListeners();
    });
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    // Random interval 3-7 minutes
    final minutes = 3 + (DateTime.now().millisecond % 5);
    _idleTimer = Timer(Duration(minutes: minutes), () {
      if (!mounted) return;
      // In AI mode, generate a contextual greeting
      if (_isAIMode && _aiService != null) {
        _showAIGreeting();
      } else {
        _showMessage();
      }
      _startIdleTimer(); // Loop
    });
  }

  Future<void> _showAIGreeting() async {
    try {
      final greeting = await _aiService!.quickAsk(
        message: 'Say a warm, playful greeting to the couple using the app. Be natural and varied — 1-2 sentences. Use an emoji.',
        systemPrompt: 'You are Everglow Guardian — a cute magical cat mascot. Respond warmly with personality.',
      );

      if (!mounted) return;
      _currentMessage = GuardianMessage(
        id: 'ai_greeting_${DateTime.now().millisecondsSinceEpoch}',
        content: greeting.isNotEmpty ? greeting : '✨ Purring with love for you two!',
        category: 'ai',
        createdAt: DateTime.now(),
      );
    } catch (_) {
      if (!mounted) return;
      // Fallback to static messages
      _showMessage();
      return;
    }

    _isMessageVisible = true;
    notifyListeners();

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        _isMessageVisible = false;
        notifyListeners();
      }
    });
  }

  void _showMessage() async {
    _messageCounter++;

    // Occasionally mention partner's mood (every 5-10 messages)
    if (_moodService != null && _authService != null &&
        _messageCounter % 7 == 0) {
      final auth = _authService;
      final moodSvc = _moodService;
      final partnerUsername = auth.partnerUsername ?? '';
      final partnerName = auth.partnerName;

      final moodStream = moodSvc.watchLatestMood(partnerUsername);
      final UserMood? latestMood = await moodStream.first;

      if (latestMood != null) {
        _currentMessage = GuardianMessage(
          id: 'partner_mood',
          content: '$partnerName is feeling ${latestMood.moodEmoji} today!',
          category: 'mood',
          createdAt: DateTime.now(),
        );
        _isMessageVisible = true;
        notifyListeners();

        Future.delayed(const Duration(seconds: 5), () {
          _isMessageVisible = false;
          notifyListeners();
        });
        return;
      }
    }

    _currentMessage = _service.getRandomMessage();
    if (_currentMessage != null) {
      _isMessageVisible = true;
      notifyListeners();

      Future.delayed(const Duration(seconds: 5), () {
        _isMessageVisible = false;
        notifyListeners();
      });
    }
  }

  void triggerMoodPrompt() {
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
    super.dispose();
  }
}
