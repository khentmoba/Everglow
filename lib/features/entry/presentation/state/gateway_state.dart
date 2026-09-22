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

  /// Offline "remember me", wired by GatewayPage -> AuthService.
  /// Returns the remembered username when [passcode] is that user's own
  /// code, null otherwise. Only consulted when the server is unreachable.
  String? Function(String passcode)? tryOfflineUnlock;

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
        // No definitive answer (offline, timeout, 5xx). If this device
        // already remembers Clair/Khent from an online login and the
        // typed code is theirs, open their saved copy offline.
        final remembered = tryOfflineUnlock?.call(_currentInput);
        if (remembered == 'khentsgdz' || remembered == 'clairjassen') {
          _lastFailureReason = null;
          _lastEnteredPasscode = _currentInput;
          updateState(GatewayState.unlocking);
          return;
        }
        // Offline but locally knowable: if the build configured couple codes,
        // we can tell whether the code matches someone. If passcodes are not
        // in this build, the server is the sole source of truth and any
        // server failure is a connection issue.
        final hasConfiguredCoupleCodes =
            EnvConfig.clairPasscode.isNotEmpty ||
            EnvConfig.khentPasscode.isNotEmpty;
        final matchesKnownCoupleCode =
            (EnvConfig.clairPasscode.isNotEmpty &&
                _currentInput == EnvConfig.clairPasscode) ||
            (EnvConfig.khentPasscode.isNotEmpty &&
                _currentInput == EnvConfig.khentPasscode);
        final matchesNobody =
            hasConfiguredCoupleCodes && !matchesKnownCoupleCode;
        _lastFailureReason = matchesNobody
            ? GatewayFailureReason.invalidCode
            : GatewayFailureReason.connection;
      }
    } else {
      // Verifier not wired (tests only): keep the old wrong-code path.
      _lastFailureReason = GatewayFailureReason.invalidCode;
    }
    // Still here: no online login and no offline unlock. Stay on the
    // gateway so a wrong code or a fresh offline device never opens the app.
    updateState(GatewayState.error);
    // Wait for shake animation
    await Future.delayed(const Duration(milliseconds: 500));
    clearInput();
    updateState(GatewayState.awaitingInput);
  }
}
