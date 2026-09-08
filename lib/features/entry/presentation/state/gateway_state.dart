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
    // Passcodes come from EnvConfig only (build-time --dart-define or .env);
    // no hardcoded literals so builds without config can't be bypassed.
    final clientPasscodes = <String>{
      if (EnvConfig.breyanPasscode.isNotEmpty) EnvConfig.breyanPasscode,
      if (EnvConfig.octagramPasscode.isNotEmpty) EnvConfig.octagramPasscode,
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
    // No offline fallback for couple codes: firestore.rules requires a real
    // non-anonymous Firebase session, so unlocking the UI locally would only
    // produce permission-denied shelves. Stay on the gateway and retry.
    updateState(GatewayState.error);
    // Wait for shake animation
    await Future.delayed(const Duration(milliseconds: 500));
    clearInput();
    updateState(GatewayState.awaitingInput);
  }
}
