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

enum GatewayFailureReason { invalidCode, connection }

class GatewayNotifier extends ChangeNotifier {
  GatewayState _currentState = GatewayState.awaitingInput;
  String _currentInput = '';
  String? _lastEnteredPasscode;
  GatewayFailureReason? _lastFailureReason;

  GatewayState get currentState => _currentState;
  String get currentInput => _currentInput;
  String? get lastEnteredPasscode => _lastEnteredPasscode;
  GatewayFailureReason? get lastFailureReason => _lastFailureReason;

  void setFailureReason(GatewayFailureReason reason) {
    _lastFailureReason = reason;
    notifyListeners();
  }

  void clearFailureReason() {
    if (_lastFailureReason != null) {
      _lastFailureReason = null;
      notifyListeners();
    }
  }

  void updateState(GatewayState newState) {
    _currentState = newState;
    notifyListeners();
  }

  void appendDigit(String digit) {
    if (_currentInput.length < 4 &&
        _currentState == GatewayState.awaitingInput) {
      _lastFailureReason = null;
      _currentInput += digit;
      notifyListeners();

      if (_currentInput.length == 4) {
        _validatePasscode();
      }
    }
  }

  void backspace() {
    if (_currentInput.isNotEmpty &&
        _currentState == GatewayState.awaitingInput) {
      _currentInput = _currentInput.substring(0, _currentInput.length - 1);
      notifyListeners();
    }
  }

  void clearInput() {
    _currentInput = '';
    notifyListeners();
  }

  Future<String?> Function(String passcode)? verifyCouplePasscode;

  String? Function(String passcode)? tryOfflineUnlock;
  bool Function()? hasOfflineRememberedCode;

  void _validatePasscode() async {
    updateState(GatewayState.evaluating);

    await Future.delayed(const Duration(milliseconds: 220));

    if (verifyCouplePasscode != null) {
      try {
        final username = await verifyCouplePasscode!(_currentInput);
        if (username != null &&
            const [
              'khentsgdz',
              'clairjassen',
              'breyan',
              'octagram',
            ].contains(username)) {
          _lastFailureReason = null;
          _lastEnteredPasscode = _currentInput;
          updateState(GatewayState.unlocking);
          return;
        }
        _lastFailureReason = GatewayFailureReason.invalidCode;
      } catch (_) {
        final remembered = tryOfflineUnlock?.call(_currentInput);
        if (remembered == 'khentsgdz' || remembered == 'clairjassen') {
          _lastFailureReason = null;
          _lastEnteredPasscode = _currentInput;
          updateState(GatewayState.unlocking);
          return;
        }
        _lastFailureReason = hasOfflineRememberedCode?.call() == true
            ? GatewayFailureReason.invalidCode
            : GatewayFailureReason.connection;
      }
    } else {
      _lastFailureReason = GatewayFailureReason.invalidCode;
    }
    updateState(GatewayState.error);
    await Future.delayed(const Duration(milliseconds: 500));
    clearInput();
    updateState(GatewayState.awaitingInput);
  }
}
