// SDK sealed types are implemented only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_test_fakes.dart';

class QueryReads {
  final List<int> limits = [];
  final List<String> orders = [];
}

/// Executes filtering, ordering, limits and cursors over synthetic records.
class PagedCollection extends TestCollection {
  final QueryReads reads;
  final String? order;
  final bool descending;
  final int? pageLimit;
  final String? cursor;
  final List<bool Function(Map<String, dynamic>)> filters;
  PagedCollection({
    required super.entries,
    QueryReads? reads,
    this.order,
    this.descending = false,
    this.pageLimit,
    this.cursor,
    this.filters = const [],
  }) : reads = reads ?? QueryReads();

  PagedCollection _copy({
    String? order,
    bool? descending,
    int? pageLimit,
    String? cursor,
    List<bool Function(Map<String, dynamic>)>? filters,
  }) => PagedCollection(
    entries: entries,
    reads: reads,
    order: order ?? this.order,
    descending: descending ?? this.descending,
    pageLimit: pageLimit ?? this.pageLimit,
    cursor: cursor ?? this.cursor,
    filters: filters ?? this.filters,
  );

  int compare(dynamic a, dynamic b) => a is Timestamp && b is Timestamp
      ? a.compareTo(b)
      : (a as Comparable).compareTo(b);

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _copy(
    filters: [
      ...filters,
      (row) =>
          (isEqualTo == null || row[field] == isEqualTo) &&
          (isLessThan == null || compare(row[field], isLessThan) < 0) &&
          (isGreaterThanOrEqualTo == null ||
              compare(row[field], isGreaterThanOrEqualTo) >= 0),
    ],
  );
  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    reads.orders.add('$field');
    return _copy(order: '$field', descending: descending);
  }

  @override
  Query<Map<String, dynamic>> limit(int pageLimit) {
    reads.limits.add(pageLimit);
    return _copy(pageLimit: pageLimit);
  }

  @override
  Query<Map<String, dynamic>> startAfterDocument(
    DocumentSnapshot documentSnapshot,
  ) => _copy(cursor: documentSnapshot.id);

  PagedSnapshot snapshot() {
    var rows = [
      for (var i = 0; i < entries.length; i++) {'_id': '$i', ...entries[i]},
    ].where((row) => filters.every((filter) => filter(row))).toList();
    if (order != null) {
      rows.sort((a, b) => compare(a[order], b[order]) * (descending ? -1 : 1));
    }
    if (cursor != null) {
      rows = rows
          .skip(rows.indexWhere((row) => row['_id'] == cursor) + 1)
          .toList();
    }
    return PagedSnapshot(
      pageLimit == null ? rows : rows.take(pageLimit!).toList(),
    );
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => snapshot();
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(snapshot());
}

class PagedSnapshot extends TestSnapshot {
  PagedSnapshot(super.entries);
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    for (final row in entries) TestEntry(row['_id'], row),
  ];
}
