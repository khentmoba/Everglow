import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_party_server.dart';

/// Data-driven list of self-hosted playback servers for the watch party.
///
/// Mirrors AniChan's `/api/watch/servers` approach: the server list is
/// configuration, not code. Everglow loads a shared list from Firestore
/// (`config/watch_party_servers`) and merges servers the user adds
/// locally (persisted in SharedPreferences). The active server is
/// stored on the room document so the partner follows automatically.
class WatchPartyServerService extends ChangeNotifier {
  static final WatchPartyServerService _instance =
      WatchPartyServerService._internal();
  factory WatchPartyServerService() => _instance;
  WatchPartyServerService._internal();

  static const String _firestoreDoc = 'config/watch_party_servers';
  static const String _prefsKey = 'watch_party_custom_servers';

  static const String functionsBase =
      'https://us-central1-everglow-1c6db.cloudfunctions.net';

  List<WatchPartyServer>? _shared;
  List<WatchPartyServer> _custom = const [];
  bool _loading = false;
  bool _loaded = false;

  /// Ordered list of all servers: shared Firestore entries first, then
  /// locally-added custom servers. Empty while the background fetch is
  /// still in flight.
  List<WatchPartyServer> get servers {
    if (!_loaded) _load();
    return [...?_shared, ..._custom];
  }

  bool get isLoading => _loading;

  WatchPartyServer? byId(String id) {
    for (final s in servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The recommended entry, or the first entry overall.
  WatchPartyServer? get defaultServer {
    final list = servers;
    for (final s in list) {
      if (s.isRecommended) return s;
    }
    return list.isNotEmpty ? list.first : null;
  }

  /// Route a stream URL through the Cloud Function passthrough proxy,
  /// mirroring AniChan's `/api/watch/m3u8` and `/api/watch/vtt` routes.
  /// Callers should only use this when [WatchPartyServer.proxyEnabled]
  /// is true; direct CORS-enabled servers can skip the hop.
  static String proxyUrlFor(String url) {
    return '$functionsBase/proxyWatchStream?url='
        '${Uri.encodeComponent(url)}';
  }

  /// Final playback URL for a server: proxied when configured, otherwise
  /// the raw stream URL.
  String resolveStreamUrl(WatchPartyServer server) {
    return server.proxyEnabled
        ? proxyUrlFor(server.streamUrl)
        : server.streamUrl;
  }

  /// Add a user-configured server and persist it locally.
  Future<WatchPartyServer> addCustomServer({
    required String name,
    required String shortName,
    required String host,
    required String type,
    required String streamUrl,
    String? subtitleUrl,
    bool proxyEnabled = false,
  }) async {
    final server = WatchPartyServer(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      shortName: shortName,
      host: host,
      type: type,
      streamUrl: streamUrl,
      subtitleUrl: subtitleUrl,
      proxyEnabled: proxyEnabled,
      isCustom: true,
    );
    _custom = [..._custom, server];
    await _saveCustom();
    notifyListeners();
    return server;
  }

  /// Remove a locally-added server.
  Future<void> removeCustomServer(String id) async {
    _custom = _custom.where((s) => s.id != id).toList();
    await _saveCustom();
    notifyListeners();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;

    try {
      final doc = await FirebaseFirestore.instance.doc(_firestoreDoc).get();
      final raw = doc.data();
      if (raw != null && raw['servers'] is List) {
        _shared = (raw['servers'] as List)
            .whereType<Map<String, dynamic>>()
            .map(WatchPartyServer.fromJson)
            .where((s) => s.id.isNotEmpty && s.streamUrl.isNotEmpty)
            .toList();
        debugPrint(
          '[WatchPartyServerService] Loaded ${_shared!.length} shared servers',
        );
      }
    } catch (e) {
      debugPrint('[WatchPartyServerService] Firestore fetch failed: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored != null && stored.isNotEmpty) {
        final raw = jsonDecode(stored) as List<dynamic>;
        _custom = raw
            .whereType<Map<String, dynamic>>()
            .map(WatchPartyServer.fromJson)
            .where((s) => s.id.isNotEmpty && s.streamUrl.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[WatchPartyServerService] Local server load failed: $e');
    }

    _shared ??= const [];
    _loading = false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _saveCustom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_custom.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[WatchPartyServerService] Save failed: $e');
    }
  }
}
