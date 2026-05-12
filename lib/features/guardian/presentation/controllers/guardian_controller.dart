import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/guardian_message.dart';
import '../../data/services/guardian_service.dart';
import '../../../heartbeat/data/services/mood_service.dart';
import '../../../heartbeat/data/models/user_mood.dart';
import '../../../../services/auth_service.dart';

enum GuardianState { idle, greeting, reacting }

class GuardianController extends ChangeNotifier {
  final GuardianService _service;
  final MoodService? _moodService;
  final AuthService? _authService;
  
  GuardianState _state = GuardianState.idle;
  GuardianMessage? _currentMessage;
  bool _isMessageVisible = false;
  bool _isMoodPromptVisible = false;
  Timer? _idleTimer;
  int _messageCounter = 0;

  GuardianController(this._service, {MoodService? moodService, AuthService? authService})
      : _moodService = moodService,
        _authService = authService;

  GuardianState get state => _state;
  GuardianMessage? get currentMessage => _currentMessage;
  bool get isMessageVisible => _isMessageVisible;
  bool get isMoodPromptVisible => _isMoodPromptVisible;

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
    _showMessage();
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
      _showMessage();
      _startIdleTimer(); // Loop
    });
  }

  void _showMessage() async {
    _messageCounter++;
    
    // Occasionally mention partner's mood (every 5-10 messages)
    if (_moodService != null && _authService != null && _messageCounter % 7 == 0) {
      final partnerUsername = _authService!.partnerUsername ?? '';
      final partnerName = _authService!.partnerName;
      
      final moodStream = _moodService!.watchLatestMood(partnerUsername);
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
