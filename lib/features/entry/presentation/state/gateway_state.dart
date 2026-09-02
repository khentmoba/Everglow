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

    // Brief pause to feel intentional but not sluggish
    await Future.delayed(const Duration(milliseconds: 220));

    // Breyan/Octagram stay client-verified (non-sensitive).
    // Keep set from EnvConfig (now always has 9132/8080 fallback).
    final clientPasscodes = <String>{
      if (EnvConfig.breyanPasscode.isNotEmpty) EnvConfig.breyanPasscode,
      if (EnvConfig.octagramPasscode.isNotEmpty) EnvConfig.octagramPasscode,
      '9132',
      '8080',
    };
    final isClientCinemaCode = clientPasscodes.contains(_currentInput);
    if (isClientCinemaCode) {
      _lastEnteredPasscode = _currentInput;
      updateState(GatewayState.unlocking);
      return;
    }
    if (verifyCouplePasscode != null) {
      try {
        final username = await verifyCouplePasscode!(_currentInput);
        if (username != null &&
            (username == 'khentsgdz' || username == 'clairjassen')) {
          _lastEnteredPasscode = _currentInput;
          updateState(GatewayState.unlocking);
          return;
        }
      } catch (_) {}
    }
    // Fallback: server offline, not configured, or verifier unwired.
    // EnvConfig now has 0221/0938 in prod too, plus hardcoded literals
    // so a Cloud Function outage never bricks the couple login.
    final fallbackOk =
        (_currentInput == EnvConfig.clairPasscode &&
            EnvConfig.clairPasscode.isNotEmpty) ||
        (_currentInput == EnvConfig.khentPasscode &&
            EnvConfig.khentPasscode.isNotEmpty) ||
        _currentInput == '0221' ||
        _currentInput == '0938';
    if (fallbackOk) {
      _lastEnteredPasscode = _currentInput;
      updateState(GatewayState.unlocking);
      return;
    }
    updateState(GatewayState.error);
    // Wait for shake animation
    await Future.delayed(const Duration(milliseconds: 500));
    clearInput();
    updateState(GatewayState.awaitingInput);
  }
}
