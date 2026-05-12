import 'package:flutter/material.dart';

enum GatewayState {
  initialLoad,
  awaitingInput,
  evaluating,
  error,
  unlocking,
  revealingSite,
  complete,
}

class GatewayNotifier extends ChangeNotifier {
  GatewayState _currentState = GatewayState.initialLoad;
  String _currentInput = '';
  String? _lastEnteredPasscode;

  GatewayState get currentState => _currentState;
  String get currentInput => _currentInput;
  String? get lastEnteredPasscode => _lastEnteredPasscode;

  void updateState(GatewayState newState) {
    _currentState = newState;
    notifyListeners();
  }

  void appendDigit(String digit) {
    if (_currentInput.length < 4 && _currentState == GatewayState.awaitingInput) {
      _currentInput += digit;
      notifyListeners();

      if (_currentInput.length == 4) {
        _validatePasscode();
      }
    }
  }

  void backspace() {
    if (_currentInput.isNotEmpty && _currentState == GatewayState.awaitingInput) {
      _currentInput = _currentInput.substring(0, _currentInput.length - 1);
      notifyListeners();
    }
  }

  void clearInput() {
    _currentInput = '';
    notifyListeners();
  }

  void _validatePasscode() async {
    updateState(GatewayState.evaluating);
    
    // Small delay to feel intentional
    await Future.delayed(const Duration(milliseconds: 500));

    if (_currentInput == '1111' || _currentInput == '2222') {
      _lastEnteredPasscode = _currentInput;
      updateState(GatewayState.unlocking);
    } else {
      updateState(GatewayState.error);
      // Wait for shake animation
      await Future.delayed(const Duration(milliseconds: 500));
      clearInput();
      updateState(GatewayState.awaitingInput);
    }
  }
}
