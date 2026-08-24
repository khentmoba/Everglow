import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../models/date_poll.dart';

class CalendarPollService {
  static final CalendarPollService _instance = CalendarPollService._internal();
  factory CalendarPollService() => _instance;
  CalendarPollService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'calendar_polls';

  Stream<List<DatePoll>> watchAll() => withFirestoreTimeout(
    _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => DatePoll.fromFirestore(d)).toList()),
    label: 'polls-all',
  );

  Stream<List<DatePoll>> watchOpen() => withFirestoreTimeout(
    _db
        .collection(_collection)
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map((d) => DatePoll.fromFirestore(d)).toList()),
    label: 'polls-open',
  );

  Future<void> create(DatePoll poll) async {
    try {
      await _db.collection(_collection).add(poll.toFirestore());
      Logger.i('Created poll: ${poll.title}');
    } catch (e) {
      Logger.e('Error creating poll', error: e);
    }
  }

  Future<void> vote(String pollId, String username, String optionId) async {
    try {
      await _db.collection(_collection).doc(pollId).update({
        'votes.$username': optionId,
      });
      Logger.i('Vote $username -> $optionId on $pollId');
    } catch (e) {
      Logger.e('Error voting', error: e);
    }
  }

  Future<void> unvote(String pollId, String username) async {
    try {
      await _db.collection(_collection).doc(pollId).update({
        'votes.$username': FieldValue.delete(),
      });
    } catch (e) {
      Logger.e('Error unvoting', error: e);
    }
  }

  Future<void> close(String pollId, String? decidedOptionId) async {
    try {
      await _db.collection(_collection).doc(pollId).update({
        'status': 'closed',
        'decidedOptionId': ?decidedOptionId,
      });
    } catch (e) {
      Logger.e('Error closing poll', error: e);
    }
  }

  Future<void> reopen(String pollId) async {
    try {
      await _db.collection(_collection).doc(pollId).update({
        'status': 'open',
        'decidedOptionId': FieldValue.delete(),
      });
    } catch (e) {
      Logger.e('Error reopening poll', error: e);
    }
  }

  Future<void> delete(String pollId) async {
    try {
      await _db.collection(_collection).doc(pollId).delete();
    } catch (e) {
      Logger.e('Error deleting poll', error: e);
    }
  }
}
