// Firestore SDK sealed types are used only as network-free test doubles.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/ai/data/services/ai_conversation_repo.dart';
import 'package:everglow/features/ai/domain/models/ai_conversation.dart';

void main() {
  late _Firestore db;
  late AIConversationRepository repo;
  late AIConversation oldConversation;
  late AIMessage oldMessage;

  setUp(() {
    db = _Firestore();
    repo = AIConversationRepository(db: db);
    oldMessage = AIMessage(role: 'user', content: 'Our current conversation');
    oldConversation = AIConversation(
      id: 'assistant',
      feature: 'assistant',
      messages: [oldMessage],
    );
    repo.setConversation('assistant', oldConversation);
  });

  void expectOldConversation() {
    expect(repo.assistant, same(oldConversation));
    expect(repo.assistant!.messages, [same(oldMessage)]);
  }

  test('listSessions propagates a read failure', () async {
    final error = StateError('List read failed');
    db.sessions.readError = error;
    await expectLater(repo.listSessions(), throwsA(same(error)));
  });

  test('watchSessions emits a synchronous setup failure as an error', () async {
    final error = StateError('Listener setup failed');
    db.sessions.watchError = error;
    await expectLater(repo.watchSessions(), emitsError(same(error)));
  });

  test('watchSessions propagates asynchronous read errors', () async {
    final error = StateError('Listener read failed');
    db.sessions.events = Stream.error(error);
    await expectLater(repo.watchSessions(), emitsError(same(error)));
  });

  test(
    'loadSession propagates a read failure without changing cache',
    () async {
      final error = StateError('Session read failed');
      db.sessions.readError = error;
      await expectLater(repo.loadSession('archive'), throwsA(same(error)));
      expectOldConversation();
    },
  );

  test(
    'loadSession fails for a missing document without changing cache',
    () async {
      await expectLater(repo.loadSession('missing'), throwsStateError);
      expectOldConversation();
    },
  );

  test(
    'loadSession fails for null document data without changing cache',
    () async {
      db.sessions.exists = true;
      await expectLater(repo.loadSession('archive'), throwsStateError);
      expectOldConversation();
    },
  );

  test(
    'a malformed later message preserves the whole old conversation',
    () async {
      db.sessions.data = {
        'messages': [
          {'role': 'user', 'content': 'Valid archived message'},
          {'role': 'assistant', 'content': 'Bad date', 'timestamp': 'invalid'},
        ],
      };
      await expectLater(repo.loadSession('archive'), throwsFormatException);
      expectOldConversation();
    },
  );

  test('loadSession replaces messages after successful parsing', () async {
    final timestamp = DateTime.utc(2026, 1, 2);
    db.sessions.data = {
      'messages': [
        {
          'role': 'user',
          'content': 'Archived question',
          'timestamp': timestamp.toIso8601String(),
        },
        {'role': 'assistant', 'content': 'Archived answer'},
      ],
      'summary': 'Not used when full messages exist',
    };
    await repo.loadSession('archive');
    expect(repo.assistant, isNot(same(oldConversation)));
    expect(oldConversation.messages, [same(oldMessage)]);
    expect(repo.assistant!.id, oldConversation.id);
    expect(repo.assistant!.createdAt, oldConversation.createdAt);
    expect(repo.assistant!.messages.map((m) => m.content), [
      'Archived question',
      'Archived answer',
    ]);
    expect(repo.assistant!.messages.first.role, 'user');
    expect(repo.assistant!.messages.first.timestamp, timestamp);
  });

  test(
    'switching keeps a finished reply snapshot intact for a pending archive',
    () async {
      final saving = Completer<void>();
      final finishedReply = AIConversation(
        id: 'assistant',
        feature: 'assistant',
        messages: List.generate(
          20,
          (i) => AIMessage(
            role: i.isEven ? 'user' : 'assistant',
            content: 'Original message $i',
          ),
        ),
      );
      repo.setConversation('assistant', finishedReply);
      // The send path checks this object after its save completes.
      final pendingArchive = saving.future.then((_) => finishedReply.toJson());
      db.sessions.data = {
        'messages': List.generate(
          4,
          (i) => {'role': 'user', 'content': 'Archived message $i'},
        ),
      };
      await repo.loadSession('archive');
      expect(repo.assistant!.messages, hasLength(4));
      saving.complete();
      final snapshot = await pendingArchive;
      expect(snapshot['messages'], hasLength(20));
      expect(finishedReply.messages.last.content, 'Original message 19');
    },
  );

  test('loadSession retains the compressed summary fallback', () async {
    db.sessions.data = {
      'messages': [],
      'hasSummary': true,
      'summary': 'We planned a movie night.',
    };
    await repo.loadSession('archive');
    expect(repo.assistant!.messages.single.role, 'assistant');
    expect(
      repo.assistant!.messages.single.content,
      'Summary: We planned a movie night.',
    );
  });

  test('list and watch retain session titles and summary metadata', () async {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 1, 2));
    db.sessions.entries = [
      _QueryDocument('full', {
        'feature': 'assistant',
        'messages': <dynamic>[
          {'role': 'user', 'content': 'Movie night ideas'},
        ],
        'hasSummary': false,
        'createdAt': timestamp,
      }),
      _QueryDocument('summary', {
        'feature': 'assistant',
        'messages': [],
        'messageCount': 4,
        'hasSummary': true,
        'summary': 'A lovely movie night',
        'createdAt': timestamp,
      }),
    ];
    final sessions = await repo.listSessions(limit: 2);
    expect(sessions.map((s) => s.id), ['full', 'summary']);
    expect(sessions.map((s) => s.title), [
      'Movie night ideas',
      'A lovely movie night',
    ]);
    expect(sessions.first.messageCount, 1);
    expect(sessions.last.messageCount, 4);
    expect(sessions.last.hasSummary, isTrue);
    expect(sessions.last.summary, 'A lovely movie night');
    expect(sessions.last.createdAt, timestamp.toDate());
    final liveSessions = await repo.watchSessions(limit: 2).first;
    expect(liveSessions.map((s) => s.title), sessions.map((s) => s.title));
    expect(db.sessions.requestedLimit, 2);
  });
}

class _Firestore implements FirebaseFirestore {
  final sessions = _Collection();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'ai_memories');
    return sessions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Mutable controls let each test inject failures at the SDK boundary.
// ignore: must_be_immutable
class _Collection implements CollectionReference<Map<String, dynamic>> {
  Object? readError;
  Object? watchError;
  Map<String, dynamic>? data;
  bool? exists;
  int? requestedLimit;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> entries = [];
  Stream<QuerySnapshot<Map<String, dynamic>>>? events;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(this, path!);

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
  }) {
    expect(field, 'feature');
    expect(isEqualTo, 'assistant');
    return this;
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    expect(field, 'createdAt');
    expect(descending, isTrue);
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int count) {
    requestedLimit = count;
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (readError != null) throw readError!;
    return _QuerySnapshot(entries);
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    if (watchError != null) throw watchError!;
    return events ?? Stream.value(_QuerySnapshot(entries));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Document implements DocumentReference<Map<String, dynamic>> {
  final _Collection sessions;
  @override
  final String id;
  _Document(this.sessions, this.id);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(id, 'shared');
    expect(path, 'sessions');
    return sessions;
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    if (sessions.readError != null) throw sessions.readError!;
    return _DocumentSnapshot(sessions.data, sessions.exists);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  final bool? existsOverride;
  _DocumentSnapshot(this.value, this.existsOverride);

  @override
  bool get exists => existsOverride ?? value != null;

  @override
  Map<String, dynamic>? data() => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  _QuerySnapshot(this.docs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QueryDocument implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> value;
  _QueryDocument(this.id, this.value);

  @override
  Map<String, dynamic> data() => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
