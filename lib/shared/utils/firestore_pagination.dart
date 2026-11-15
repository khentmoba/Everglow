import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/firestore_stream_utils.dart';

class FirestorePage<T> {
  const FirestorePage({required this.items, required this.nextCursor});

  final List<T> items;

  final DocumentSnapshot? nextCursor;

  bool get hasMore => nextCursor != null;
}

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
  final snap = await withGetTimeout(q.get(), label: 'paginated list page');
  final items = snap.docs.map(fromDoc).toList();
  final next = snap.docs.length < limit ? null : snap.docs.last;
  return FirestorePage(items: items, nextCursor: next);
}
