import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/dashboard/data/services/letterbox_service.dart';
import '../../features/xp/data/services/xp_service.dart';
import '../config/env_config.dart';
import '../router/route_memory.dart';
import '../utils/firestore_stream_utils.dart';
import '../utils/logger.dart';

/// Thrown by [AuthService.verifyCouplePasscode] when no endpoint returned a
/// definitive wrong-code answer (offline, timeout, 5xx). Lets the gateway
/// show "couldn't connect" instead of "wrong code".
class PasscodeConnectionException implements Exception {
  final String? detail;
  const PasscodeConnectionException([this.detail]);
  @override
  String toString() =>
      'PasscodeConnectionException${detail == null ? '' : ': $detail'}';
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  String? _currentUser;
  String? _partnerUid;
  String? _partnerNameResolved;
  bool _hasTrustedIdentity = false;
  bool _isSyncingIdentity = false;
  bool _isResolvingPartner = false;
  bool _isSessionLoaded = false;
  String? _lastAuthError;
  bool _offlineUnlocked = false;

  AuthService() {
    _loadSession();
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _hasTrustedIdentity = false;
      if (user == null) {
        _partnerUid = null;
        _partnerNameResolved = null;
        _isResolvingPartner = false;
      } else if (_currentUser != null) {
        if (user.isAnonymous && isCoupleUser) {
          Logger.e(
            '[AuthService] clearing anonymous session for couple user $_currentUser — real login required',
          );
          unawaited(_auth.signOut());
        } else {
          _queueServerIdentitySync();
        }
      }
      notifyListeners();
    });
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUser = prefs.getString('current_user_name');
      if (_currentUser != null) {
        Logger.i("Restored session for: $_currentUser");
        // Same heal as the auth-state listener: a persisted anonymous user
        // with a couple username can never read couple data. Sign out so the
        // gateway asks for a real login instead of showing empty shelves.
        if (isCoupleUser && _auth.currentUser?.isAnonymous == true) {
          Logger.e(
            '[AuthService] clearing persisted anonymous session for $_currentUser — real login required',
          );
          try {
            await _auth.signOut();
          } catch (e) {
            Logger.e('Failed to clear anonymous session', error: e);
          }
          _user = null;
        }
        notifyListeners();
        // Auth state can fire before the remembered username is loaded.
        if (_auth.currentUser != null && !_hasTrustedIdentity) {
          _queueServerIdentitySync();
        }
      }
    } catch (e) {
      Logger.e('Failed to load session from disk', error: e);
    } finally {
      _isSessionLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveSession(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      await prefs.setString('current_user_name', name);
    } else {
      await prefs.remove('current_user_name');
    }
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  String? get currentUser => _currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isSessionLoaded => _isSessionLoaded;

  /// True when the Firebase session is anonymous. Anonymous sessions are
  /// blocked by firestore.rules on every app read, so one paired with a
  /// couple username can only ever produce permission-denied streams.
  bool get isAnonymousSession => _auth.currentUser?.isAnonymous == true;

  /// Single-line auth diagnosis for the browser console. The dashboard
  /// logs this on load so a permission-denied report always carries the
  /// session facts needed to tell a guest session from a missing role claim.
  String get diagLine =>
      'uid=${_auth.currentUser?.uid ?? 'none'} '
      'anonymous=$isAnonymousSession '
      'username=${_currentUser ?? 'none'} '
      'offlineMode=$_offlineUnlocked '
      'trustedIdentity=$_hasTrustedIdentity';

  /// True when this session was unlocked offline from the remembered user
  /// (see [tryOfflineRememberedLogin]). The dashboard shows cached data
  /// with an offline banner until the next successful online login.
  bool get isOfflineMode => _offlineUnlocked;

  /// True once both Firebase Auth and SharedPreferences have resolved.
  /// Dashboard and partner-dependent features should wait for this.
  /// An offline-remembered session also counts as ready: the dashboard
  /// renders cached Firestore data instead of spinning forever.
  bool get isReady =>
      _currentUser != null &&
      ((_hasTrustedIdentity && _user != null) || _offlineUnlocked);

  /// Dynamically resolved partner UID from the server-owned /users profiles.
  String? get partnerUid => _partnerUid;

  /// True while partner UID resolution is in flight. Presence widgets use
  /// this to show a linking state instead of the unavailable fallback.
  bool get isResolvingPartner => _isResolvingPartner;

  /// Re-runs partner UID resolution on demand. Safe to call repeatedly and
  /// from any screen: concurrent calls are ignored and transient failures
  /// preserve the last known [partnerUid] instead of clearing it.
  /// Screens that depend on the partner link (Sanctuary, watch party) should
  /// call this after ensuring the user doc so a single failed background
  /// resolve no longer sticks until the next full re-login.
  Future<void> refreshPartnerLink() => _resolvePartnerInfo();

  /// Partner display name resolved alongside [partnerUid].
  String get partnerName => _partnerNameResolved ?? 'Partner';

  String? get partnerUsername {
    if (_currentUser == 'clairjassen') return 'khentsgdz';
    if (_currentUser == 'khentsgdz') return 'clairjassen';
    return null;
  }

  /// True if the signed-in user is a cinema-only profile (Breyan, Octagram).
  /// They get access to the Cinema feature but not the partner-only data.
  bool get isCinemaOnlyUser =>
      _currentUser == 'breyan' || _currentUser == 'octagram';

  /// True if the signed-in user is one half of the couple (Khent or Clair).
  /// These two accounts share the "Our Cinema" list; everyone else does not.
  bool get isCoupleUser =>
      _currentUser == 'khentsgdz' || _currentUser == 'clairjassen';

  /// Last authentication error message, if any. Cleared on successful login.
  String? get lastAuthError => _lastAuthError;

  /// Ensures the user is authenticated with a real account based on their passcode
  Future<void> loginWithPasscode(String username) async {
    String email;
    String password;

    if (username == 'clairjassen' || username == 'khentsgdz') {
      throw StateError('Couple access must use server passcode verification');
    } else if (username == 'breyan') {
      email = EnvConfig.breyanEmail;
      password = EnvConfig.breyanPassword;
    } else if (username == 'octagram') {
      email = EnvConfig.octagramEmail;
      password = EnvConfig.octagramPassword;
    } else {
      throw StateError('Unknown username: $username');
    }

    if (email.isEmpty || password.isEmpty) {
      _lastAuthError =
          '$username credentials are not configured for this build.';
      Logger.e(_lastAuthError!);
      return;
    }

    try {
      Logger.d("Attempting login for $username ($email)...");
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _currentUser = username;
      await _saveSession(username);
      await _syncServerIdentity();
      _lastAuthError = null;
      _offlineUnlocked = false;
      Logger.i(
        "Successfully logged in as $username (UID: ${_auth.currentUser?.uid})",
      );
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      Logger.e('Login failed with FirebaseAuthException', error: e);
      _lastAuthError = 'Authentication failed: ${e.message ?? e.code}';
      Logger.e(
        'Passcode login failed for $username — account must exist; client never auto-registers',
        error: e,
      );
    } catch (e) {
      _lastAuthError = 'Could not verify this account with the server.';
      Logger.e('Identity bootstrap failed after login', error: e);
      await _auth.signOut();
      _user = null;
      _currentUser = null;
      _hasTrustedIdentity = false;
      await _saveSession(null);
    } finally {
      notifyListeners();
    }
  }

  /// Ensures the user is authenticated with Firebase (anonymously if needed)
  Future<void> ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      // Anonymous sessions are blocked by firestore.rules, so silently
      // creating one would only produce a broken "guest" experience.
      Logger.e(
        'Authentication required; anonymous fallback is disabled by security rules.',
      );
    }
  }

  /// Sets a user-facing auth error without exposing underlying exceptions.
  void setAuthError(String message) {
    _lastAuthError = message;
  }

  void _queueServerIdentitySync() {
    unawaited(
      _syncServerIdentity().catchError((Object error) {
        Logger.e('[AuthService] server identity sync failed', error: error);
      }),
    );
  }

  /// Exchanges the authenticated Firebase account for server-issued role
  /// claims and a server-owned profile. The client never writes /users.
  Future<void> _syncServerIdentity() async {
    final user = _auth.currentUser;
    if (user == null || _currentUser == null) return;
    if (_hasTrustedIdentity || _isSyncingIdentity) return;
    _isSyncingIdentity = true;

    try {
      final idToken = await user.getIdToken();
      final appCheckToken = await FirebaseAppCheck.instance.getToken();
      if (idToken == null || idToken.isEmpty || appCheckToken == null) {
        throw StateError('Firebase identity token unavailable');
      }

      final isLocalWeb =
          kIsWeb &&
          (Uri.base.host == 'localhost' ||
              Uri.base.host == '127.0.0.1' ||
              Uri.base.host == '0.0.0.0');
      final urls = <Uri>[
        if (kIsWeb && !isLocalWeb) Uri.parse('/api/bootstrapProfile'),
        Uri.parse(
          'https://us-central1-everglow-1c6db.cloudfunctions.net/bootstrapProfile',
        ),
      ];

      http.Response? response;
      Object? lastError;
      for (final url in urls) {
        try {
          final candidate = await http
              .post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $idToken',
                  'X-Firebase-AppCheck': appCheckToken,
                },
              )
              .timeout(const Duration(seconds: 10));
          if (candidate.statusCode == 200) {
            response = candidate;
            break;
          }
          lastError = 'HTTP ${candidate.statusCode}: ${candidate.body}';
        } catch (error) {
          lastError = error;
        }
      }
      if (response == null) {
        throw StateError('Profile bootstrap failed: $lastError');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final username = data['username'] as String?;
      if (username == null || username.isEmpty) {
        throw const FormatException('Profile bootstrap returned no username');
      }
      await user.getIdToken(true);
      _currentUser = username;
      await _saveSession(username);
      _hasTrustedIdentity = true;
      _offlineUnlocked = false;
      _lastAuthError = null;
      Logger.i(
        '[AuthService] trusted identity ready for $username (${user.uid})',
      );
      notifyListeners();

      unawaited(
        Future.wait([
          _resolvePartnerInfo().catchError((Object e) {
            Logger.e('AuthService._resolvePartnerInfo failed (bg)', error: e);
          }),
          XPService().initializeProgress(user.uid).catchError((Object e) {
            Logger.e('XP init failed (bg)', error: e);
          }),
          if (isCoupleUser)
            LetterboxService().ensureSeeded().catchError((Object e) {
              Logger.e('Letterbox seed failed (bg)', error: e);
            }),
        ]),
      );
    } finally {
      _isSyncingIdentity = false;
    }
  }

  /// Queries /users to find the partner's UID by username. If the partner's
  /// account was recreated, this automatically finds their new UID.
  ///
  /// Transient failures (offline, permission-denied before the own user doc
  /// is visible) preserve the last known [_partnerUid] so presence widgets
  /// keep working instead of flipping to the unavailable state. Only a
  /// definitive answer (no partner for this profile, or a successful query
  /// with zero matches) clears the link. Retry at any time via
  /// [refreshPartnerLink].
  Future<void> _resolvePartnerInfo() async {
    if (_isResolvingPartner) return;
    if (_currentUser == null || _auth.currentUser == null) return;
    _isResolvingPartner = true;
    notifyListeners();

    try {
      var partnerUser = partnerUsername;
      try {
        final ownDoc = await withGetTimeout(
          FirebaseFirestore.instance
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .get(),
          label: 'auth own user-doc read',
        );
        final storedPartner = ownDoc.data()?['partnerUsername'] as String?;
        if (storedPartner != null && storedPartner.isNotEmpty) {
          partnerUser = storedPartner;
        }
      } catch (e) {
        Logger.e(
          "AuthService._resolvePartnerInfo own doc read failed",
          error: e,
        );
      }

      // Cinema-only profiles have no partner; clear decisively.
      if (partnerUser == null) {
        _partnerUid = null;
        _partnerNameResolved = null;
        return;
      }

      try {
        final db = FirebaseFirestore.instance;
        // Fetch every doc claiming the partner username instead of just the
        // first. Firestore orders such a query by document id, and stray or
        // re-created docs sort ahead of the real account, which used to point
        // the couple at a doc with no garden / presence / chat data.
        final query = await withGetTimeout(
          db
              .collection('users')
              .where('username', isEqualTo: partnerUser)
              .limit(10)
              .get(),
          label: 'auth partner lookup',
        );

        final partnerUid = pickPartnerUid([
          for (final doc in query.docs) (id: doc.id, data: doc.data()),
        ], myUsername: _currentUser);

        if (partnerUid != null) {
          _partnerUid = partnerUid;
          _partnerNameResolved = partnerUser == 'khentsgdz' ? 'Khent' : 'Clair';
        } else {
          // Partner has never synced a /users doc on this project yet.
          _partnerUid = null;
          _partnerNameResolved = null;
        }
      } catch (e) {
        Logger.e("AuthService._resolvePartnerInfo failed", error: e);
        // Keep the last known UID so a transient error does not stick the
        // UI in the unavailable state; the next refresh will correct it.
      }
    } finally {
      _isResolvingPartner = false;
      notifyListeners();
    }
  }

  /// Picks the real partner account when `/users` holds more than one doc
  /// with the same username. Duplicates come from re-created accounts and
  /// from stray docs, and Firestore returns them ordered by document id, so
  /// the first match is not necessarily the account the partner uses.
  ///
  /// Ranking:
  /// 1. docs whose `partnerUsername` links back to [myUsername] — the mutual
  ///    link written on every login by the current app,
  /// 2. then the most recently updated doc,
  /// 3. then the document id, so the result is always deterministic.
  @visibleForTesting
  static String? pickPartnerUid(
    List<({String id, Map<String, dynamic> data})> docs, {
    required String? myUsername,
  }) {
    if (docs.isEmpty) return null;
    final ranked = List.of(docs)
      ..sort((a, b) {
        final aLinksBack = _linksBackTo(a.data, myUsername);
        final bLinksBack = _linksBackTo(b.data, myUsername);
        if (aLinksBack != bLinksBack) return aLinksBack ? -1 : 1;
        final byUpdated = _docUpdatedAt(
          b.data,
        ).compareTo(_docUpdatedAt(a.data));
        if (byUpdated != 0) return byUpdated;
        return a.id.compareTo(b.id);
      });
    return ranked.first.id;
  }

  static bool _linksBackTo(Map<String, dynamic> data, String? myUsername) {
    if (myUsername == null || myUsername.isEmpty) return false;
    return data['partnerUsername'] == myUsername;
  }

  /// Reads a users-doc `updatedAt` for ranking. Docs without one sort last.
  static DateTime _docUpdatedAt(Map<String, dynamic> data) {
    final value = data['updatedAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Server-verified Khent/Clair passcode -> Firebase custom token.
  /// Returns username (khentsgdz/clairjassen) on success, null on bad code.
  /// Throws [PasscodeConnectionException] when no endpoint gave a
  /// definitive answer (offline, timeout, 5xx) so the gateway can tell
  /// "wrong code" apart from "couldn't connect".
  Future<String?> verifyCouplePasscode(String passcode) async {
    final isLocalWeb =
        kIsWeb &&
        (Uri.base.host == 'localhost' ||
            Uri.base.host == '127.0.0.1' ||
            Uri.base.host == '0.0.0.0');
    // Try hosting rewrite first (same-origin, no CORS), then direct CF URL.
    // On local dev web, skip relative /api/ because the local dev server serves index.html.
    final urls = <Uri>[
      if (kIsWeb && !isLocalWeb) Uri.parse('/api/verifyPasscode'),
      Uri.parse(
        'https://us-central1-everglow-1c6db.cloudfunctions.net/verifyPasscode',
      ),
      Uri.parse('https://everglow-1c6db.web.app/api/verifyPasscode'),
    ];
    Object? lastError;
    for (final url in urls) {
      try {
        final appCheckToken = await FirebaseAppCheck.instance
            .getLimitedUseToken();
        final resp = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'X-Firebase-AppCheck': appCheckToken,
              },
              body: jsonEncode({'passcode': passcode}),
            )
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 400 ||
            (resp.statusCode == 401 && resp.body.contains('passphrase'))) {
          return null;
        }
        if (resp.statusCode != 200) {
          lastError = 'HTTP ${resp.statusCode}: ${resp.body}';
          Logger.e('verifyCouplePasscode $url -> $lastError');
          continue;
        }
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        final username = data['username'] as String?;
        if (token == null || token.isEmpty || username == null) {
          lastError = 'missing token/username';
          Logger.e('verifyCouplePasscode missing token/username from $url');
          continue;
        }
        try {
          await _auth.signInWithCustomToken(token);
        } catch (e) {
          lastError = e;
          Logger.e('verifyCouplePasscode sign-in failed via $url', error: e);
          continue;
        }
        _currentUser = username;
        await _saveSession(username);
        await _syncServerIdentity();
        return _currentUser;
      } catch (e) {
        lastError = e;
        if (_auth.currentUser != null) {
          await _auth.signOut();
          _hasTrustedIdentity = false;
        }
        Logger.e('verifyCouplePasscode $url failed', error: e);
      }
    }
    // No endpoint gave a definitive wrong-code answer and none succeeded:
    // the network or server is at fault, not the code itself.
    throw PasscodeConnectionException(lastError?.toString());
  }

  /// Offline "remember me" for Khent/Clair when the server is unreachable.
  ///
  /// Only the already-remembered user (saved by a previous online login)
  /// can unlock, and only with their own code — this never switches users
  /// and never unlocks a fresh device. Returns the username on success.
  /// Firestore still serves its local cache in this mode, so previously
  /// opened chats, notes, and garden keep showing until back online.
  String? tryOfflineRememberedLogin(String passcode) {
    final remembered = _currentUser;
    if (!offlineCodeMatches(
      rememberedUser: remembered,
      passcode: passcode,
      clairCode: EnvConfig.clairPasscode,
      khentCode: EnvConfig.khentPasscode,
    )) {
      return null;
    }
    _offlineUnlocked = true;
    _lastAuthError = null;
    Logger.i('[AuthService] offline remembered login for $remembered');
    notifyListeners();
    return remembered;
  }

  /// Pure rule behind [tryOfflineRememberedLogin]: the typed code must be
  /// the remembered user's own code. Never switches users, never unlocks
  /// a fresh device (null remembered user), and empty configured codes
  /// never match so builds without config can't be bypassed.
  @visibleForTesting
  static bool offlineCodeMatches({
    required String? rememberedUser,
    required String passcode,
    required String clairCode,
    required String khentCode,
  }) {
    if (passcode.isEmpty) return false;
    if (rememberedUser == 'clairjassen') {
      return clairCode.isNotEmpty && passcode == clairCode;
    }
    if (rememberedUser == 'khentsgdz') {
      return khentCode.isNotEmpty && passcode == khentCode;
    }
    return false;
  }

  /// Offline fallback for Khent/Clair when verifyPasscode is unreachable.
  ///
  /// Anonymous Firebase sessions are blocked by firestore.rules
  /// (`isNotAnonymous` is required for every app read), so signing in
  /// anonymously would only produce permission-denied streams and
  /// false-empty shelves. Refuse instead with a visible error so the
  /// gateway stays put and the user retries online. Server verification
  /// will sign in the real account on the next online login.
  Future<void> loginCoupleOffline(String username) async {
    if (username != 'khentsgdz' && username != 'clairjassen') return;
    _lastAuthError =
        'Login server unreachable. Please connect to the internet and try again.';
    Logger.e(
      'loginCoupleOffline refused anonymous couple session for $username — real login required',
    );
    notifyListeners();
  }

  /// Direct login for Breyan/Octagram (client-verified, non-sensitive).
  /// Passcodes come from EnvConfig only (build-time --dart-define or .env);
  /// no hardcoded literals so builds without config can't be bypassed.
  Future<bool> loginCinemaWithPasscode(String passcode) async {
    if (EnvConfig.breyanPasscode.isNotEmpty &&
        passcode == EnvConfig.breyanPasscode) {
      await loginWithPasscode('breyan');
      return lastAuthError == null;
    }
    if (EnvConfig.octagramPasscode.isNotEmpty &&
        passcode == EnvConfig.octagramPasscode) {
      await loginWithPasscode('octagram');
      return lastAuthError == null;
    }
    return false;
  }

  Future<void> logout() async {
    await _auth.signOut();
    // Forget the last page: the next login on this device starts fresh
    // instead of reopening the previous user's screen.
    await RouteMemory.clear();
    _currentUser = null;
    _partnerUid = null;
    _partnerNameResolved = null;
    _isResolvingPartner = false;
    _hasTrustedIdentity = false;
    _offlineUnlocked = false;
    await _saveSession(null);
    notifyListeners();
  }
}
