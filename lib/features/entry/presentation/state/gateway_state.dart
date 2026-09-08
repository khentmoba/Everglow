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

/// Why the last passcode attempt failed.
///
/// `invalidCode` means the server understood the request and said no.
/// `connection` means we never got a definitive answer (offline,
/// timeout, 5xx). The gateway shows a different line for each so a
/// wrong code never feels like a server problem.
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

  /// Lets the page report a post-validation failure (e.g. the code was
  /// right but the Firebase session never materialised) as a connection
  /// problem instead of a wrong code.
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
      // A new attempt clears the previous failure line so the error
      // message never lingers once Clair starts typing again.
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
          _lastFailureReason = null;
          _lastEnteredPasscode = _currentInput;
          updateState(GatewayState.unlocking);
          return;
        }
        // Server answered definitively: the code is simply wrong.
        _lastFailureReason = GatewayFailureReason.invalidCode;
      } catch (_) {
        // No definitive answer (offline, timeout, 5xx): this is a
        // connection problem, not a wrong code.
        _lastFailureReason = GatewayFailureReason.connection;
      }
    } else {
      // Verifier not wired (tests only): keep the old wrong-code path.
      _lastFailureReason = GatewayFailureReason.invalidCode;
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
