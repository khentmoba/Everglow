import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/agent/agent_fixtures.dart';
import '../../../../core/agent/agent_mode.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../models/user_mood.dart';

import '../../../../core/utils/logger.dart';

class MoodSource {
  Future<void> submitMood({
    required String username,
    required int score,
    required String emoji,
    HeartNeed? need,
  }) => throw UnimplementedError();

  Future<bool> hasSubmittedToday(String username) => throw UnimplementedError();

  Future<UserMood?> getLatestMood(String username) =>
      throw UnimplementedError();

  Stream<UserMood?> watchLatestMood(String username) =>
      throw UnimplementedError();
}

class MoodService implements MoodSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _demoMoods = <String, UserMood>{};
  final _demoChanges = StreamController<void>.broadcast();

  UserMood _demoMood(String username) =>
      _demoMoods[username] ??
      UserMood(
        id: 'demo_$username',
        username: username,
        moodScore: AgentFixtures.demoMood.moodScore,
        moodEmoji: AgentFixtures.demoMood.moodEmoji,
        need: username == 'clairjassen' ? HeartNeed.company : null,
        timestamp: DateTime.now(),
      );

  Stream<UserMood?> _watchDemo(String username) async* {
    yield _demoMood(username);
    yield* _demoChanges.stream.map((_) => _demoMood(username));
  }

  @visibleForTesting
  static String dateKeyFor(DateTime when) =>
      '${when.year.toString().padLeft(4, '0')}-'
      '${when.month.toString().padLeft(2, '0')}-'
      '${when.day.toString().padLeft(2, '0')}';

  @override
  Future<void> submitMood({
    required String username,
    required int score,
    required String emoji,
    HeartNeed? need,
  }) async {
    if (AgentMode.isActive.value) {
      _demoMoods[username] = UserMood(
        id: 'demo_$username',
        username: username,
        moodScore: score,
        moodEmoji: emoji,
        need: need,
        timestamp: DateTime.now(),
      );
      _demoChanges.add(null);
      return;
    }
    await _db.collection('moods').add({
      'username': username,
      'uid': username,
      'date': dateKeyFor(DateTime.now()),
      'moodScore': score,
      'moodEmoji': emoji,
      if (need != null) 'need': need.name,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acknowledge(UserMood mood, String username) async {
    if (!mood.isCurrentAt(DateTime.now()) ||
        mood.need == null ||
        mood.id == null) {
      throw StateError('This check-in has expired');
    }
    if (AgentMode.isActive.value) {
      _demoMoods[mood.username] = UserMood(
        id: mood.id,
        username: mood.username,
        moodScore: mood.moodScore,
        moodEmoji: mood.moodEmoji,
        timestamp: mood.timestamp,
        need: mood.need,
        acknowledgedBy: username,
      );
      _demoChanges.add(null);
      return;
    }
    try {
      await _db.collection('moods').doc(mood.id).update({
        'acknowledgedBy': username,
      });
    } catch (e) {
      Logger.e('Could not acknowledge mood', error: e);
      rethrow;
    }
  }

  @override
  Future<bool> hasSubmittedToday(String username) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return true;
    }
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await withGetTimeout(
      _db
          .collection('moods')
          .where('username', isEqualTo: username)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get(),
      label: 'mood today check',
    );

    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<UserMood?> getLatestMood(String username) async {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return _demoMood(username);
    }
    try {
      final snapshot = await withGetTimeout(
        _db
            .collection('moods')
            .where('username', isEqualTo: username)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get(),
        label: 'mood latest',
      );
      if (snapshot.docs.isEmpty) return null;
      return UserMood.fromFirestore(
        snapshot.docs.first.data(),
        id: snapshot.docs.first.id,
      );
    } catch (e) {
      Logger.e('MoodService.getLatestMood failed for $username', error: e);
      return null;
    }
  }

  @override
  Stream<UserMood?> watchLatestMood(String username) {
    if (AgentMode.isActive.value && AgentMode.useDemoData.value) {
      return _watchDemo(username);
    }
    return withFirestoreTimeout(
      _db
          .collection('moods')
          .where('username', isEqualTo: username)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) return null;
            return UserMood.fromFirestore(
              snapshot.docs.first.data(),
              id: snapshot.docs.first.id,
            );
          }),
      label: 'mood-$username',
    );
  }
}
