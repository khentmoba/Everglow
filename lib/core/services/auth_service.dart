import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/gallery/data/services/offline_photos.dart';
import '../../features/dashboard/data/services/letterbox_service.dart';
import '../../features/xp/data/services/xp_service.dart';
import '../agent/agent_mode.dart';
import '../router/route_memory.dart';
import '../utils/firestore_stream_utils.dart';
import 'notification_service.dart';
import '../utils/logger.dart';

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
  bool _hasSyncedUserDoc = false;
  bool _isResolvingPartner = false;
  bool _isSessionLoaded = false;
  String? _lastAuthError;
  bool _offlineUnlocked = false;
  Map<String, dynamic>? _offlineVerifier;
  bool _isAgentSession = false;

  bool get hasOfflineRememberedCode =>
      isCoupleUser && _offlineVerifier?['username'] == _currentUser;

  bool get isAgentSession => _isAgentSession;

  AuthService() {
    _loadSession();
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _hasSyncedUserDoc = false;
      if (user == null) {
        if (!_isAgentSession) {
          _partnerUid = null;
          _partnerNameResolved = null;
          _isResolvingPartner = false;
        }
      } else if (_currentUser != null) {
        if (user.isAnonymous && isCoupleUser) {
          Logger.e(
            '[AuthService] clearing anonymous session for couple user $_currentUser — real login required',
          );
          unawaited(_auth.signOut());
        } else {
          unawaited(_syncUserDoc());
        }
      }
      notifyListeners();
    });
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isAgentSession) return;
      _currentUser = prefs.getString('current_user_name');
      final savedVerifier = prefs.getString('offline_passcode_verifier');
      if (savedVerifier != null) {
        _offlineVerifier = jsonDecode(savedVerifier) as Map<String, dynamic>;
      }
      if (_currentUser != null) {
        Logger.i("Restored session for: $_currentUser");
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
        if (_auth.currentUser != null && !_hasSyncedUserDoc) {
          unawaited(_syncUserDoc());
        }
      }
    } catch (e) {
      Logger.e('Failed to load session from disk', error: e);
    } finally {
      if (!_isAgentSession) {
        _isSessionLoaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> _saveSession(String? name, {String? passcode}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      await prefs.setString('current_user_name', name);
    } else {
      await prefs.remove('current_user_name');
    }
    _offlineVerifier = passcode == null || name == null
        ? null
        : buildOfflineVerifier(name, passcode);
    if (_offlineVerifier == null) {
      await prefs.remove('offline_passcode_verifier');
    } else {
      await prefs.setString(
        'offline_passcode_verifier',
        jsonEncode(_offlineVerifier),
      );
    }
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null || _isAgentSession;
  String? get currentUser => _currentUser;
  String? get uid =>
      _isAgentSession ? 'agent_${_currentUser}_uid' : _auth.currentUser?.uid;
  bool get isSessionLoaded => _isSessionLoaded;

  bool get isAnonymousSession =>
      !_isAgentSession && _auth.currentUser?.isAnonymous == true;

  String get diagLine =>
      'uid=${uid ?? 'none'} '
      'anonymous=$isAnonymousSession '
      'username=${_currentUser ?? 'none'} '
      'offlineMode=$_offlineUnlocked '
      'usersDocSynced=$_hasSyncedUserDoc '
      'agentSession=$_isAgentSession';

  bool get isOfflineMode => _offlineUnlocked;

  bool get isReady =>
      _currentUser != null && (_user != null || _offlineUnlocked);

  String? get partnerUid => _partnerUid;

  bool get isResolvingPartner => _isResolvingPartner;

  Future<void> refreshPartnerLink() => _resolvePartnerInfo();

  String get partnerName => _partnerNameResolved ?? 'Partner';

  String? get partnerUsername {
    if (_currentUser == 'clairjassen') return 'khentsgdz';
    if (_currentUser == 'khentsgdz') return 'clairjassen';
    return null;
  }

  bool get isCinemaOnlyUser =>
      _currentUser == 'breyan' || _currentUser == 'octagram';

  bool get isCoupleUser =>
      _currentUser == 'khentsgdz' || _currentUser == 'clairjassen';

  String? get lastAuthError => _lastAuthError;

  void enableAgentSession({String profile = 'khentsgdz'}) {
    if (!AgentMode.canActivate) return;
    if (_isAgentSession && _currentUser == profile) return;
    _isAgentSession = true;
    _currentUser = profile;
    _offlineUnlocked = true;
    _isSessionLoaded = true;
    _lastAuthError = null;
    if (profile == 'breyan' || profile == 'octagram') {
      _partnerUid = null;
      _partnerNameResolved = null;
    } else {
      _partnerUid = 'agent_demo_partner_uid';
      _partnerNameResolved = profile == 'khentsgdz' ? 'Clair' : 'Khent';
    }
    Logger.i('[AuthService] Agent session enabled as $profile');
    notifyListeners();
  }

  Future<void> ensureAuthenticated() async {
    if (_auth.currentUser == null && !_isAgentSession) {
      Logger.e(
        'Authentication required; anonymous fallback is disabled by security rules.',
      );
    }
  }

  void setAuthError(String message) {
    _lastAuthError = message;
  }

  Future<void> _syncUserDoc() async {
    if (_isAgentSession) return;
    final myUid = _auth.currentUser?.uid;
    if (myUid == null || _currentUser == null) return;
    if (_hasSyncedUserDoc) return;
    _hasSyncedUserDoc = true;

    final db = FirebaseFirestore.instance;
    try {
      final identity = await _auth.currentUser!.getIdTokenResult();
      if (identity.signInProvider == 'password' && isCinemaOnlyUser) {
        _currentUser = null;
        _user = null;
        _hasSyncedUserDoc = false;
        await _saveSession(null);
        await _auth.signOut();
        notifyListeners();
        return;
      }
      if (identity.claims?['username'] != _currentUser) {
        _hasSyncedUserDoc = false;
        return;
      }
      await db.collection('users').doc(myUid).set({
        'username': _currentUser,
        'partnerUsername': partnerUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Logger.i('[AuthService] users doc synced for $_currentUser ($myUid)');
      unawaited(NotificationService.instance.syncAuthSession(enabled: true));

      unawaited(
        Future.wait([
          _resolvePartnerInfo().catchError((Object e) {
            Logger.e('AuthService._resolvePartnerInfo failed (bg)', error: e);
          }),
          XPService().initializeProgress(myUid).catchError((Object e) {
            Logger.e('XP init failed (bg)', error: e);
          }),
          if (isCoupleUser)
            LetterboxService().ensureSeeded().catchError((Object e) {
              Logger.e('Letterbox seed failed (bg)', error: e);
            }),
        ]),
      );
    } catch (e) {
      var repaired = false;
      try {
        repaired = await _repairStaleUserDoc(db, myUid);
      } catch (e2) {
        Logger.e(
          '[AuthService] users doc repair failed for $_currentUser ($myUid)',
          error: e2,
        );
      }
      if (!repaired) {
        _hasSyncedUserDoc = false;
        Logger.e(
          '[AuthService] _syncUserDoc failed for $_currentUser ($myUid)',
          error: e,
        );
      } else {
        unawaited(NotificationService.instance.syncAuthSession(enabled: true));
      }
    }
  }

  Future<bool> _repairStaleUserDoc(FirebaseFirestore db, String myUid) async {
    final doc = await getDocFast(
      db.collection('users').doc(myUid),
      label: 'auth stale user-doc check',
    );
    if (!doc.exists) return false;
    final data = doc.data() ?? {};
    if (!needsUserDocRepair(data, _currentUser)) return false;
    Logger.i(
      '[AuthService] repairing stale users doc for $_currentUser ($myUid)',
    );
    await db.collection('users').doc(myUid).delete();
    await db.collection('users').doc(myUid).set({
      'username': _currentUser,
      'partnerUsername': partnerUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    Logger.i('[AuthService] users doc repaired for $_currentUser ($myUid)');
    return true;
  }

  @visibleForTesting
  static bool needsUserDocRepair(
    Map<String, dynamic> data,
    String? currentUser,
  ) {
    const allowed = {'username', 'partnerUsername', 'updatedAt', 'createdAt'};
    if (data['username'] != currentUser) return true;
    return !data.keys.every(allowed.contains);
  }

  Future<void> _resolvePartnerInfo() async {
    if (_isAgentSession || _isResolvingPartner) return;
    if (_currentUser == null || _auth.currentUser == null) return;
    _isResolvingPartner = true;
    notifyListeners();

    try {
      var partnerUser = partnerUsername;
      try {
        final ownDoc = await getDocFast(
          FirebaseFirestore.instance
              .collection('users')
              .doc(_auth.currentUser!.uid),
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

      if (partnerUser == null) {
        _partnerUid = null;
        _partnerNameResolved = null;
        return;
      }

      try {
        final db = FirebaseFirestore.instance;
        final query = await getQueryFast(
          db
              .collection('users')
              .where('username', isEqualTo: partnerUser)
              .limit(10),
          label: 'auth partner lookup',
        );

        final partnerUid = pickPartnerUid([
          for (final doc in query.docs) (id: doc.id, data: doc.data()),
        ], myUsername: _currentUser);

        if (partnerUid != null) {
          _partnerUid = partnerUid;
          _partnerNameResolved = partnerUser == 'khentsgdz' ? 'Khent' : 'Clair';
        } else {
          _partnerUid = null;
          _partnerNameResolved = null;
        }
      } catch (e) {
        Logger.e("AuthService._resolvePartnerInfo failed", error: e);
      }
    } finally {
      _isResolvingPartner = false;
      notifyListeners();
    }
  }

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

  Future<String?> verifyCouplePasscode(String passcode) async {
    final isLocalWeb =
        kIsWeb &&
        (Uri.base.host == 'localhost' ||
            Uri.base.host == '127.0.0.1' ||
            Uri.base.host == '0.0.0.0');
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
        final resp = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'passcode': passcode}),
            )
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 401 || resp.statusCode == 400) {
          return null;
        }
        if (resp.statusCode != 200) {
          lastError = 'HTTP ${resp.statusCode}';
          Logger.e(
            'verifyCouplePasscode $url -> ${resp.statusCode}: ${resp.body}',
          );
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
        _isAgentSession = false;
        await _saveSession(username, passcode: isCoupleUser ? passcode : null);
        unawaited(_syncUserDoc());
        _lastAuthError = null;
        _offlineUnlocked = false;
        notifyListeners();
        return username;
      } catch (e) {
        lastError = e;
        Logger.e('verifyCouplePasscode $url failed', error: e);
      }
    }
    throw PasscodeConnectionException(lastError?.toString());
  }

  String? tryOfflineRememberedLogin(String passcode) {
    final remembered = _currentUser;
    if (!offlineCodeMatches(
      rememberedUser: remembered,
      passcode: passcode,
      verifier: _offlineVerifier,
    )) {
      return null;
    }
    _offlineUnlocked = true;
    _lastAuthError = null;
    Logger.i('[AuthService] offline remembered login for $remembered');
    notifyListeners();
    return remembered;
  }

  @visibleForTesting
  static Map<String, String> buildOfflineVerifier(
    String username,
    String passcode,
  ) {
    final random = Random.secure();
    final salt = base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
    return {
      'username': username,
      'salt': salt,
      'digest': _offlineDigest(username, salt, passcode),
    };
  }

  static String _offlineDigest(String username, String salt, String passcode) =>
      sha256.convert(utf8.encode('$username:$salt:$passcode')).toString();

  @visibleForTesting
  static bool offlineCodeMatches({
    required String? rememberedUser,
    required String passcode,
    required Map<String, dynamic>? verifier,
  }) {
    if (!{'clairjassen', 'khentsgdz'}.contains(rememberedUser) ||
        !RegExp(r'^\d{4}$').hasMatch(passcode) ||
        verifier?['username'] != rememberedUser) {
      return false;
    }
    final salt = verifier?['salt'];
    final digest = verifier?['digest'];
    return salt is String &&
        salt.isNotEmpty &&
        digest is String &&
        digest == _offlineDigest(rememberedUser!, salt, passcode);
  }

  Future<void> loginCoupleOffline(String username) async {
    if (username != 'khentsgdz' && username != 'clairjassen') return;
    _lastAuthError =
        'Login server unreachable. Please connect to the internet and try again.';
    Logger.e(
      'loginCoupleOffline refused anonymous couple session for $username — real login required',
    );
    notifyListeners();
  }

  Future<void> logout() async {
    _isAgentSession = false;
    try {
      await NotificationService.instance.unregisterForLogout();
    } catch (e) {
      _lastAuthError =
          'Could not log out safely. Check your connection and try again.';
      Logger.e('Logout blocked because push cleanup failed', error: e);
      notifyListeners();
      rethrow;
    }
    _lastAuthError = null;
    await _auth.signOut();
    await RouteMemory.clear();
    _currentUser = null;
    _partnerUid = null;
    _partnerNameResolved = null;
    _isResolvingPartner = false;
    _hasSyncedUserDoc = false;
    _offlineUnlocked = false;
    await _saveSession(null);
    await AgentMode.clearPersistedState();
    await OfflinePhotos.instance.clear();
    notifyListeners();
  }
}
