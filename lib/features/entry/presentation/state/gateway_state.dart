import 'package:flutter/material.dart';

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

enum GatewayFailureReason { invalidCode, connection }

class GatewayNotifier extends ChangeNotifier {
  static const int passphraseMinLength = 16;

  GatewayState _currentState = GatewayState.awaitingInput;
  String _currentInput = '';
  String? _lastEnteredPasscode;
  GatewayFailureReason? _lastFailureReason;

  GatewayState get currentState => _currentState;
  String get currentInput => _currentInput;
  String? get lastEnteredPasscode => _lastEnteredPasscode;
  GatewayFailureReason? get lastFailureReason => _lastFailureReason;

  bool get canSubmit {
    final cinemaCodes = <String>{
      if (EnvConfig.breyanPasscode.isNotEmpty) EnvConfig.breyanPasscode,
      if (EnvConfig.octagramPasscode.isNotEmpty) EnvConfig.octagramPasscode,
    };
    return _currentInput.trim().length >= passphraseMinLength ||
        cinemaCodes.contains(_currentInput);
  }

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

  void updateInput(String value) {
    if (_currentState != GatewayState.awaitingInput) return;
    final next = value.length <= 256 ? value : value.substring(0, 256);
    if (next == _currentInput) return;
    _lastFailureReason = null;
    _currentInput = next;
    notifyListeners();
  }

  void backspace() {
    if (_currentInput.isEmpty || _currentState != GatewayState.awaitingInput) {
      return;
    }
    _currentInput = _currentInput.substring(0, _currentInput.length - 1);
    notifyListeners();
  }

  void clearInput() {
    _currentInput = '';
    notifyListeners();
  }

  void submit() {
    if (_currentState == GatewayState.awaitingInput && canSubmit) {
      _validatePasscode();
    }
  }

  Future<String?> Function(String passcode)? verifyCouplePasscode;
  String? Function(String passcode)? tryOfflineUnlock;

  Future<void> _validatePasscode() async {
    updateState(GatewayState.evaluating);
    await Future.delayed(const Duration(milliseconds: 220));

    final cinemaCodes = <String>{
      if (EnvConfig.breyanPasscode.isNotEmpty) EnvConfig.breyanPasscode,
      if (EnvConfig.octagramPasscode.isNotEmpty) EnvConfig.octagramPasscode,
    };
    if (cinemaCodes.contains(_currentInput)) {
      _lastEnteredPasscode = _currentInput;
      updateState(GatewayState.unlocking);
      return;
    }

    if (verifyCouplePasscode != null) {
      try {
        final username = await verifyCouplePasscode!(_currentInput);
        if (username == 'khentsgdz' || username == 'clairjassen') {
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

        final hasConfiguredCoupleCodes =
            EnvConfig.clairPasscode.isNotEmpty ||
            EnvConfig.khentPasscode.isNotEmpty;
        final matchesKnownCoupleCode =
            (EnvConfig.clairPasscode.isNotEmpty &&
                _currentInput == EnvConfig.clairPasscode) ||
            (EnvConfig.khentPasscode.isNotEmpty &&
                _currentInput == EnvConfig.khentPasscode);
        _lastFailureReason = hasConfiguredCoupleCodes && !matchesKnownCoupleCode
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
