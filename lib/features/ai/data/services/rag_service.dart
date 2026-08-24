import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/logger.dart';

// Lightweight Khoj-style RAG — keyword search across couple collections.
// No embeddings yet (future: cosine similarity via getEmbedding). For now TF keyword.
class RagResult {
  final String source; // e.g., Journal, Starlight, Calendar, Recipe
  final String title;
  final String snippet;
  final DateTime? date;
  final String docId;

  const RagResult({
    required this.source,
    required this.title,
    required this.snippet,
    this.date,
    required this.docId,
  });
}

class RagService {
  static final RagService _instance = RagService._internal();
  factory RagService() => _instance;
  RagService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<RagResult>> search(String query, {int limit = 5}) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    final results = <RagResult>[];
    try {
      final futures = await Future.wait([
        _searchCollection(
          'journal_entries',
          q,
          30,
          (data, id) => RagResult(
            source: 'Journal',
            title: data['title'] ?? 'Journal',
            snippet: (data['content'] ?? '').toString().substring(
              0,
              (data['content']?.toString().length ?? 0) > 120
                  ? 120
                  : (data['content']?.toString().length ?? 0),
            ),
            date: (data['createdAt'] as Timestamp?)?.toDate(),
            docId: id,
          ),
        ),
        _searchCollection(
          'starlight_jar',
          q,
          20,
          (data, id) => RagResult(
            source: 'Starlight',
            title: (data['content'] ?? '').toString().substring(0, 40),
            snippet: data['content'] ?? '',
            date: (data['timestamp'] as Timestamp?)?.toDate(),
            docId: id,
          ),
        ),
        _searchCollection(
          'calendar_events',
          q,
          20,
          (data, id) => RagResult(
            source: 'Calendar',
            title: data['title'] ?? '',
            snippet: data['description'] ?? '',
            date: (data['date'] as Timestamp?)?.toDate(),
            docId: id,
          ),
        ),
        _searchCollection(
          'recipes',
          q,
          20,
          (data, id) => RagResult(
            source: 'Recipe',
            title: data['title'] ?? '',
            snippet: data['description'] ?? '',
            date: (data['createdAt'] as Timestamp?)?.toDate(),
            docId: id,
          ),
        ),
        _searchCollection(
          'wiki_pages',
          q,
          20,
          (data, id) => RagResult(
            source: 'Wiki',
            title: data['title'] ?? '',
            snippet: data['markdown'] ?? '',
            date: (data['updatedAt'] as Timestamp?)?.toDate(),
            docId: id,
          ),
        ),
        _searchCollection(
          'budget_transactions',
          q,
          20,
          (data, id) => RagResult(
            source: 'Budget',
            title: data['title'] ?? '',
            snippet: '${data['category']} • ₱${data['amount']}',
            date: (data['date'] as Timestamp?)?.toDate(),
            docId: id,
          ),
        ),
      ]);
      for (final list in futures) {
        results.addAll(list);
      }
      // Rank by simple keyword presence + recency
      results.sort((a, b) {
        final aScore = _score(a, q);
        final bScore = _score(b, q);
        if (bScore != aScore) return bScore.compareTo(aScore);
        if (a.date != null && b.date != null) return b.date!.compareTo(a.date!);
        return 0;
      });
      return results.take(limit).toList();
    } catch (e) {
      Logger.e('RAG search failed', error: e);
      return [];
    }
  }

  double _score(RagResult r, String q) {
    double s = 0;
    if (r.title.toLowerCase().contains(q)) s += 3;
    if (r.snippet.toLowerCase().contains(q)) s += 2;
    if (r.source.toLowerCase() == 'journal' &&
        r.snippet.toLowerCase().contains(q)) {
      s += 1.5;
    }
    return s;
  }

  Future<List<RagResult>> _searchCollection(
    String col,
    String q,
    int fetchLimit,
    RagResult Function(Map<String, dynamic>, String) mapper,
  ) async {
    try {
      final snap = await _db.collection(col).limit(fetchLimit).get();
      final out = <RagResult>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final haystack =
            '${data['title'] ?? ''} ${data['content'] ?? ''} ${data['markdown'] ?? ''} ${data['description'] ?? ''} ${data['caption'] ?? ''} ${data['searchKey'] ?? ''}'
                .toLowerCase();
        if (haystack.contains(q)) {
          out.add(mapper(data, doc.id));
        }
      }
      return out;
    } catch (e) {
      Logger.e('RAG $col failed', error: e);
      return [];
    }
  }

  Future<String> buildRagContext(String query) async {
    final results = await search(query, limit: 6);
    if (results.isEmpty) return '';
    final buf = StringBuffer('## Retrieved Context (Khoj RAG)\n');
    for (final r in results) {
      buf.writeln(
        '- [${r.source}] ${r.title}: ${r.snippet.replaceAll('\n', ' ').substring(0, r.snippet.length > 180 ? 180 : r.snippet.length)}',
      );
    }
    return buf.toString();
  }
}
