import 'package:cloud_firestore/cloud_firestore.dart';

/// One page of a cursor-paginated Firestore list.
class FirestorePage<T> {
  const FirestorePage({required this.items, required this.nextCursor});

  final List<T> items;

  /// Pass back into [fetchFirestorePage] as `cursor` for the next page.
  /// Null when the collection is exhausted.
  final DocumentSnapshot? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// Generic cursor pagination over an ordered collection query.
///
/// Applies `orderBy(field, descending)` + `limit` + optional
/// `startAfterDocument(cursor)`, maps docs with [fromDoc], and returns
/// the last doc as the next cursor (null when fewer than [limit] docs
/// came back, meaning the end was reached).
Future<FirestorePage<T>> fetchFirestorePage<T>({
  required CollectionReference<Map<String, dynamic>> collection,
  required String orderBy,
  bool descending = true,
  DocumentSnapshot? cursor,
  int limit = 20,
  required T Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDoc,
  Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> q)?
  constrain,
}) async {
  Query<Map<String, dynamic>> q = collection;
  if (constrain != null) q = constrain(q);
  q = q.orderBy(orderBy, descending: descending).limit(limit);
  if (cursor != null) q = q.startAfterDocument(cursor);
  final snap = await q.get();
  final items = snap.docs.map(fromDoc).toList();
  final next = snap.docs.length < limit ? null : snap.docs.last;
  return FirestorePage(items: items, nextCursor: next);
}
