import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../../core/utils/logger.dart';
import '../models/book_item.dart';

/// One chapter extracted from an EPUB spine item.
class EpubChapter {
  final String title;
  final String body;
  const EpubChapter({required this.title, required this.body});
}

/// Result of [EpubService.loadChapters].
class EpubResult {
  final List<EpubChapter> chapters;
  final String usedUrl;
  final String? error;

  const EpubResult({required this.chapters, required this.usedUrl, this.error});

  factory EpubResult.empty(String error) =>
      EpubResult(chapters: const [], usedUrl: '', error: error);

  bool get isSuccess => chapters.isNotEmpty;
}

/// Minimal EPUB reader backend: fetches the EPUB file through the
/// `proxyBookFile` Cloud Function (gutenberg.org sends no CORS
/// headers, so the browser cannot fetch it directly), unzips it
/// with the pure-Dart `archive` package, and turns the OPF spine
/// into plain-text chapters the existing reader UI already knows
/// how to show.
///
/// EPUB structure recap (all we rely on):
///   * `META-INF/container.xml` points at the `.opf` package file.
///   * The OPF manifest maps ids to XHTML files; the spine orders them.
///   * Each spine file becomes one chapter: title from `<title>` /
///     first heading, body from tags-stripped text.
class EpubService {
  static final EpubService _instance = EpubService._internal();
  factory EpubService() => _instance;
  EpubService._internal();

  static const int _maxSpineItems = 300;
  static const int _maxFileBytes = 7 * 1024 * 1024;

  static const String _proxyUrl = String.fromEnvironment(
    'EPUB_PROXY_URL',
    defaultValue: 'https://everglow-1c6db.web.app/api/proxyBookFile',
  );

  static const bool _useFunctionsEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static String get _proxyEndpoint {
    if (_useFunctionsEmulator) {
      return 'http://localhost:5001/everglow-1c6db/us-central1/proxyBookFile';
    }
    return _proxyUrl;
  }

  /// Candidate EPUB file URLs for a book, derived from its source
  /// id. Gutenberg ids (`pg1342`) map to the canonical EPUB URLs;
  /// Internet Archive ids map to the item's `<id>.epub` file.
  List<String> candidatesFor(BookItem item) {
    final iaId = item.iaId;
    if (iaId.startsWith('pg') && iaId.length > 2) {
      final id = iaId.substring(2);
      return [
        'https://www.gutenberg.org/ebooks/$id.epub.images',
        'https://www.gutenberg.org/ebooks/$id.epub.noimages',
      ];
    }
    if (iaId.isNotEmpty) {
      return ['https://archive.org/download/$iaId/$iaId.epub'];
    }
    return const [];
  }

  /// Fetch the first working EPUB from [urls] and extract chapters.
  Future<EpubResult> loadChapters(List<String> urls) async {
    if (urls.isEmpty) return EpubResult.empty('No EPUB source available.');
    final bytes = await _fetchBytes(urls);
    if (bytes == null) {
      return EpubResult.empty(
        'Tried ${urls.length} EPUB source(s); none responded.',
      );
    }
    try {
      final chapters = parseChapters(bytes.data, fallbackTitle: '');
      if (chapters.isEmpty) {
        return EpubResult.empty('This EPUB has no readable chapters.');
      }
      return EpubResult(chapters: chapters, usedUrl: bytes.usedUrl);
    } catch (e) {
      Logger.e('EPUB parse error', error: e);
      return EpubResult.empty('Could not open this EPUB file.');
    }
  }

  // ── FETCH ──────────────────────────────────────────────────────────

  /// Fetch EPUB bytes via the Cloud Function proxy (CORS-safe).
  /// Falls back to a direct fetch, which works where the host
  /// sends CORS headers (archive.org) — e.g. on native or when the
  /// proxy is unreachable.
  Future<({Uint8List data, String usedUrl})?> _fetchBytes(
    List<String> urls,
  ) async {
    try {
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      final response = await http
          .post(
            Uri.parse(_proxyEndpoint),
            headers: {
              'Content-Type': 'application/json',
              if (idToken.isNotEmpty) 'Authorization': 'Bearer $idToken',
            },
            body: json.encode({'urls': urls}),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final base64 = data['base64'] as String? ?? '';
        if (base64.isNotEmpty) {
          final bytes = base64Decode(base64);
          if (bytes.length <= _maxFileBytes) {
            return (
              data: Uint8List.fromList(bytes),
              usedUrl: (data['usedUrl'] as String?) ?? '',
            );
          }
        }
      }
    } catch (e) {
      Logger.e('proxyBookFile error', error: e);
    }
    for (final url in urls) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200 &&
            response.bodyBytes.length <= _maxFileBytes &&
            _looksLikeZip(response.bodyBytes)) {
          return (
            data: response.bodyBytes,
            usedUrl: url,
          );
        }
      } catch (e) {
        Logger.e('EPUB direct fetch failed ($url)', error: e);
      }
    }
    return null;
  }

  bool _looksLikeZip(Uint8List bytes) =>
      bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4b;

  // ── PARSE ──────────────────────────────────────────────────────────
  //
  // A tiny purpose-built parser (regex over container.xml / OPF /
  // XHTML) instead of an XML package: EPUB package files are small
  // and regular, and this keeps the dependency footprint at one
  // pure-Dart zip package.

  /// Unzip [bytes] and extract plain-text chapters in spine order.
  /// Pure function of the bytes — unit-tested without network.
  static List<EpubChapter> parseChapters(
    Uint8List bytes, {
    String fallbackTitle = 'Book',
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile) files[file.name] = file;
    }
    final opfPath = _findOpfPath(files);
    if (opfPath == null) return const [];
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';
    final opfFile = files[opfPath];
    if (opfFile == null) return const [];
    final opf = _decode(opfFile);
    if (opf.isEmpty) return const [];
    final spineHrefs = _spineHrefs(opf);
    if (spineHrefs.isEmpty) return const [];

    final chapters = <EpubChapter>[];
    for (final href in spineHrefs.take(_maxSpineItems)) {
      final path = _resolve(opfDir, href);
      final file = files[path] ?? files[Uri.decodeFull(path)];
      if (file == null) continue;
      final html = _decode(file);
      if (html.isEmpty) continue;
      final body = htmlToText(html);
      if (body.trim().isEmpty) continue;
      final title = _chapterTitle(html, chapters.length + 1, fallbackTitle);
      chapters.add(EpubChapter(title: title, body: body));
    }
    return chapters;
  }

  static String? _findOpfPath(Map<String, ArchiveFile> files) {
    final container = files['META-INF/container.xml'];
    if (container == null) {
      // Some producers skip the container: fall back to any .opf.
      for (final name in files.keys) {
        if (name.toLowerCase().endsWith('.opf')) return name;
      }
      return null;
    }
    final xml = _decode(container);
    final match = RegExp(
      'full-path\\s*=\\s*["\']([^"\']+\\.opf)["\']',
      caseSensitive: false,
    ).firstMatch(xml);
    if (match != null) return Uri.decodeFull(match.group(1)!);
    for (final name in files.keys) {
      if (name.toLowerCase().endsWith('.opf')) return name;
    }
    return null;
  }

  /// Spine XHTML hrefs in reading order.
  static List<String> _spineHrefs(String opf) {
    final manifest = <String, String>{};
    final itemPattern = RegExp('<item\\b[^>]*>', caseSensitive: false);
    for (final m in itemPattern.allMatches(opf)) {
      final tag = m.group(0)!;
      final id = _attr(tag, 'id');
      final href = _attr(tag, 'href');
      final media = _attr(tag, 'media-type');
      if (id.isEmpty || href.isEmpty) continue;
      // Only XHTML content documents can be chapters.
      if (media.isNotEmpty &&
          !media.contains('html') &&
          !media.contains('xhtml') &&
          !media.contains('xml')) {
        continue;
      }
      manifest[id] = href;
    }
    final hrefs = <String>[];
    final refPattern = RegExp(
      '<itemref\\b[^>]*idref\\s*=\\s*["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    for (final m in refPattern.allMatches(opf)) {
      final href = manifest[m.group(1)];
      if (href != null && href.isNotEmpty) hrefs.add(href);
    }
    return hrefs;
  }

  static String _attr(String tag, String name) {
    final match = RegExp(
      '$name\\s*=\\s*["\']([^"\']*)["\']',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1) ?? '';
  }

  static String _resolve(String baseDir, String href) {
    final clean = href.split('#').first;
    if (clean.startsWith('/')) return clean.substring(1);
    final parts = <String>[...baseDir.split('/'), ...clean.split('/')];
    final resolved = <String>[];
    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (resolved.isNotEmpty) resolved.removeLast();
      } else {
        resolved.add(part);
      }
    }
    return resolved.join('/');
  }

  static String _decode(ArchiveFile file) {
    try {
      return utf8.decode(file.content as List<int>);
    } catch (_) {
      try {
        return latin1.decode(file.content as List<int>);
      } catch (_) {
        return '';
      }
    }
  }

  static String _chapterTitle(String html, int number, String fallbackTitle) {
    final titleMatch = RegExp(
      '<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    final title = _cleanInline(titleMatch?.group(1) ?? '');
    if (title.isNotEmpty && title.length <= 120) return title;
    final headingMatch = RegExp(
      '<h[1-3][^>]*>(.*?)</h[1-3]>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    final heading = _cleanInline(headingMatch?.group(1) ?? '');
    if (heading.isNotEmpty && heading.length <= 120) return heading;
    if (fallbackTitle.isNotEmpty) return '$fallbackTitle · Part $number';
    return 'Chapter $number';
  }

  /// Strip an XHTML spine document down to readable plain text.
  /// Block boundaries become newlines so paragraphs survive.
  static String htmlToText(String html) {
    var text = html;
    // Drop scripts, styles, and comments wholesale.
    text = text.replaceAll(
      RegExp('<script[\\s\\S]*?</script>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp('<style[\\s\\S]*?</style>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp('<!--[\\s\\S]*?-->'), '');
    // Block ends become line breaks.
    text = text.replaceAll(
      RegExp('</(p|h[1-6]|div|li|tr|blockquote|section|article)\\b[^>]*>', caseSensitive: false),
      '\n\n',
    );
    text = text.replaceAll(RegExp('<br\\b[^>]*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp('<[^>]+>'), '');
    text = _unescape(text);
    return text
        .replaceAll(RegExp(r'[ \t\xa0]+'), ' ')
        .replaceAll(RegExp(r'\n[ \t]+\n'), '\n\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _cleanInline(String raw) {
    return _unescape(
      raw.replaceAll(RegExp('<[^>]+>'), ' '),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _unescape(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAllMapped(
          RegExp('&#(\\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
        );
  }
}
