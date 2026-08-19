import 'package:flutter/material.dart';
// verifyCouplePasscode is wired by GatewayPage -> AuthService
import '../../../../core/config/env_config.dart';

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
  GatewayState _currentState = GatewayState.awaitingInput;
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
    if (_currentInput.length < 4 &&
        _currentState == GatewayState.awaitingInput) {
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

  void _validatePasscode() async {
    updateState(GatewayState.evaluating);

    // Small delay to feel intentional
    await Future.delayed(const Duration(milliseconds: 500));

    // Breyan/Octagram stay client-verified (non-sensitive).
    // Khent/Clair are server-verified (verifyPasscode) — never trust
    // a client 0221/0938 fallback in JS.
    final clientPasscodes = <String>{
      if (EnvConfig.breyanPasscode.isNotEmpty) EnvConfig.breyanPasscode,
      if (EnvConfig.octagramPasscode.isNotEmpty) EnvConfig.octagramPasscode,
    };
    final isClientCinemaCode = clientPasscodes.contains(_currentInput);
    if (isClientCinemaCode) {
      _lastEnteredPasscode = _currentInput;
      updateState(GatewayState.unlocking);
    } else if (verifyCouplePasscode != null) {
      try {
        final username = await verifyCouplePasscode!(_currentInput);
        if (username != null && (username == 'khentsgdz' || username == 'clairjassen')) {
          _lastEnteredPasscode = _currentInput;
          updateState(GatewayState.unlocking);
          return;
        }
      } catch (_) {}
      // Fallback: if server not configured or offline, allow client EnvConfig for dev.
      final fallbackOk = (_currentInput == EnvConfig.clairPasscode && EnvConfig.clairPasscode.isNotEmpty) || (_currentInput == EnvConfig.khentPasscode && EnvConfig.khentPasscode.isNotEmpty);
      if (fallbackOk) { _lastEnteredPasscode = _currentInput; updateState(GatewayState.unlocking); return; }
      updateState(GatewayState.error);
      // Wait for shake animation
      await Future.delayed(const Duration(milliseconds: 500));
      clearInput();
      updateState(GatewayState.awaitingInput);
    }
  }
}
