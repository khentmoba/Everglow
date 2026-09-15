import 'book_item.dart';

/// A WeLib-style search result. Carries everything a WeLib result
/// row and detail page show: cover, rating, a compact metadata line
/// ("pdf · English · 2020 · 2.9 MB"), available file formats with
/// download URLs, and the resolved in-app read source.
///
/// The catalog is aggregated from legal public-domain sources
/// (Open Library, Project Gutenberg via Gutendex, Internet Archive)
/// instead of a shadow-library catalog, but the surface mirrors
/// WeLib: same meta line, same action set (Listen / Read /
/// Download / Share / Save).
class BookSearchResult {
  final String title;
  final String author;
  final String coverUrl;
  final String year;
  final String language;
  final String publisher;
  final int pageCount;

  /// Primary file type shown in the meta line (pdf, epub, txt...).
  final String filetype;

  /// File size in MB for the primary file, when known.
  final double? sizeMb;

  /// Goodreads-style rating (0..5) and vote count, when available.
  final double? rating;
  final int? ratingCount;

  final String description;
  final List<String> subjects;

  /// ISBN-10 / ISBN-13 when the source catalog provides them
  /// (Open Library search docs carry an `isbn` list).
  final String isbn;
  final String isbn13;

  /// Category / subject slugs for the Z-Lib style category browse.
  final List<String> categories;

  /// Human label of the source catalog ("Project Gutenberg", ...).
  final String sourceLabel;

  /// Source identifiers used to resolve reading/downloads.
  final String workKey;
  final String iaId;
  final int gutenbergId;

  /// Downloads keyed by lowercase extension: txt, epub, mobi, pdf...
  final Map<String, String> downloadUrls;

  /// Candidate plain-text URLs for the in-app reader, in priority
  /// order (same contract as [OpenLibraryService.buildReadSourceCandidates]).
  final List<String> readCandidates;

  const BookSearchResult({
    required this.title,
    this.author = '',
    this.coverUrl = '',
    this.year = '',
    this.language = '',
    this.publisher = '',
    this.pageCount = 0,
    this.filetype = '',
    this.sizeMb,
    this.rating,
    this.ratingCount,
    this.description = '',
    this.subjects = const [],
    this.isbn = '',
    this.isbn13 = '',
    this.categories = const [],
    this.sourceLabel = '',
    this.workKey = '',
    this.iaId = '',
    this.gutenbergId = 0,
    this.downloadUrls = const {},
    this.readCandidates = const [],
  });

  String get id => workKey.isNotEmpty
      ? workKey
      : (gutenbergId > 0 ? 'pg$gutenbergId' : (iaId.isNotEmpty ? iaId : title));

  /// Z-Lib style file line: "EPUB, 2.9 MB" — extension first so the
  /// eye can scan a dense result list.
  String get fileLine {
    final ext = filetype.isNotEmpty
        ? filetype.toUpperCase()
        : (downloadUrls.isNotEmpty
              ? downloadUrls.keys.first.toUpperCase()
              : '');
    if (ext.isEmpty) return '';
    if (sizeMb != null && sizeMb! > 0) {
      return '$ext, ${sizeMb!.toStringAsFixed(1)} MB';
    }
    return ext;
  }

  /// All known download extensions, EPUB-first for the detail page.
  List<String> get extensions {
    final exts = downloadUrls.keys.toList();
    exts.sort((a, b) => _extRank(a).compareTo(_extRank(b)));
    return exts;
  }

  static int _extRank(String ext) {
    switch (ext) {
      case 'epub':
        return 0;
      case 'pdf':
        return 1;
      case 'txt':
        return 2;
      case 'mobi':
        return 3;
      case 'azw3':
        return 4;
      case 'fb2':
        return 5;
      case 'html':
        return 6;
      default:
        return 7;
    }
  }

  /// WeLib meta line: "pdf · English · 2020 · 2.9 MB".
  String get metaLine {
    final parts = <String>[
      if (filetype.isNotEmpty) filetype.toLowerCase(),
      if (language.isNotEmpty) language,
      if (year.isNotEmpty) year,
      if (sizeMb != null && sizeMb! > 0) '${sizeMb!.toStringAsFixed(1)} MB',
    ];
    return parts.join(' · ');
  }

  bool get hasRating => rating != null && rating! > 0;

  BookSearchResult copyWith({
    String? title,
    String? author,
    String? coverUrl,
    String? year,
    String? language,
    String? publisher,
    int? pageCount,
    String? filetype,
    double? sizeMb,
    double? rating,
    int? ratingCount,
    String? description,
    List<String>? subjects,
    String? isbn,
    String? isbn13,
    List<String>? categories,
    String? sourceLabel,
    String? workKey,
    String? iaId,
    int? gutenbergId,
    Map<String, String>? downloadUrls,
    List<String>? readCandidates,
  }) {
    return BookSearchResult(
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      year: year ?? this.year,
      language: language ?? this.language,
      publisher: publisher ?? this.publisher,
      pageCount: pageCount ?? this.pageCount,
      filetype: filetype ?? this.filetype,
      sizeMb: sizeMb ?? this.sizeMb,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      description: description ?? this.description,
      subjects: subjects ?? this.subjects,
      isbn: isbn ?? this.isbn,
      isbn13: isbn13 ?? this.isbn13,
      categories: categories ?? this.categories,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      workKey: workKey ?? this.workKey,
      iaId: iaId ?? this.iaId,
      gutenbergId: gutenbergId ?? this.gutenbergId,
      downloadUrls: downloadUrls ?? this.downloadUrls,
      readCandidates: readCandidates ?? this.readCandidates,
    );
  }

  /// Convert to the persisted [BookItem] shape so the read list,
  /// reader, and detail screens can all consume this result.
  BookItem toBookItem({String status = '', String userName = ''}) {
    final readUrl = readCandidates.isNotEmpty ? readCandidates.first : '';
    return BookItem(
      id: '',
      workKey: workKey,
      iaId: iaId.isNotEmpty ? iaId : (gutenbergId > 0 ? 'pg$gutenbergId' : ''),
      title: title,
      author: author,
      coverUrl: coverUrl,
      year: year,
      pageCount: pageCount,
      subjects: subjects,
      status: status,
      userName: userName,
      addedAt: DateTime.now(),
      readSourceUrl: readUrl,
      readSourceLabel: sourceLabel,
    );
  }
}

/// Arguments passed to the book detail route.
class BookDetailArgs {
  final BookItem item;
  final BookSearchResult? result;
  const BookDetailArgs({required this.item, this.result});
}
