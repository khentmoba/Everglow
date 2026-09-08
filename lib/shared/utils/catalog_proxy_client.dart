import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Shared helper for keyless public JSON catalogs (Open Library, Jikan).
///
/// Routes through the `proxyCatalog` Cloud Function (allow-listed to those
/// two hosts, 5-minute edge cache) so the browser never calls third parties
/// directly. Sends the Firebase ID token when signed in; the proxy
/// validates it when present and still serves anonymous callers.
class CatalogProxyClient {
  CatalogProxyClient({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String proxyBase =
      'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyCatalog';

  Future<http.Response> get(
    String base,
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 12),
  }) {
    final rawQuery = query == null || query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query).query}';
    final uri = Uri.parse(proxyBase).replace(
      queryParameters: {'base': base, 'path': '$path$rawQuery'},
    );
    return _getWithOptionalAuth(uri, timeout);
  }

  Future<http.Response> _getWithOptionalAuth(
    Uri uri,
    Duration timeout,
  ) async {
    String? token;
    try {
      token = await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      // Firebase not initialized (e.g. unit tests or early boot): continue anonymously.
    }
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return _client.get(uri, headers: headers).timeout(timeout);
  }
}
