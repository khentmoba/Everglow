import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/audio/audio_service.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/models/user_progress.dart';

class XpAward {
  final int amount;
  final int dailyCap;

  const XpAward(this.amount, this.dailyCap);
}

class XPService {
  static final XPService _instance = XPService._internal();
  factory XPService() => _instance;
  XPService._internal([FirebaseFirestore? firestore])
      : _customFirestore = firestore;

  @visibleForTesting
  XPService.withFirestore(FirebaseFirestore firestore)
      : _customFirestore = firestore;

  static const XpAward moodAward = XpAward(20, 1);
  static const XpAward journalAward = XpAward(30, 2);
  static const XpAward gardenAward = XpAward(10, 1);
  static const XpAward starAward = XpAward(15, 3);
  static const XpAward listenAward = XpAward(2, 30);
  static const XpAward playAward = XpAward(3, 20);
  static const XpAward dedicateAward = XpAward(15, 5);

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Serializes progress writes so concurrent awards on boot (e.g. listen
  /// + garden) execute in FIFO order without overwriting each other or
  /// contending on Firestore locks.
  Future<void> _lastOp = Future.value();

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _lastOp = _lastOp.then((_) async {
      try {
        final res = await task();
        completer.complete(res);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static String _todayKey([DateTime? date]) {
    final now = date ?? DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  @visibleForTesting
  static String todayKey([DateTime? date]) => _todayKey(date);

  Stream<UserProgress?> watchProgress(String uid) {
    return withFirestoreTimeout(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc('main')
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) return null;
            return UserProgress.fromMap(uid, snapshot.data()!);
          }),
      label: 'xp-progress',
    );
  }

  Future<void> addXp(String uid, int amount) async {
    await _addUncapped(uid, amount);
  }

  Future<void> _addUncapped(String uid, int amount) {
    return _enqueue(() async {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc('main');

      try {
        final snapshot = await docRef.get().timeout(const Duration(seconds: 8));

        if (!snapshot.exists) {
          await docRef.set({
            'xpTotal': amount,
            'level': UserProgress.levelForXp(amount),
            'streak': 1,
            'lastActivity': FieldValue.serverTimestamp(),
          });
        } else {
          final data = snapshot.data() ?? <String, dynamic>{};
          final rawXp = data['xpTotal'];
          final currentXp =
              rawXp is int ? rawXp : (rawXp as num?)?.toInt() ?? 0;
          final newXp = currentXp + amount;
          final newLevel = UserProgress.levelForXp(newXp);

          await docRef.update({
            'xpTotal': newXp,
            'level': newLevel,
            'lastActivity': FieldValue.serverTimestamp(),
          });

          final storedLevel = (data['level'] as num?)?.toInt() ?? 1;
          if (newLevel > storedLevel) {
            AudioService().playSfx(AudioService.levelUp);
          } else {
            AudioService().playSfx(AudioService.sparkle);
          }
        }
      } on TimeoutException {
        Logger.w('XP addXp timed out');
      } catch (e) {
        Logger.e('XP addXp failed', error: e);
      }
    });
  }

  Future<bool> awardDaily(String uid, String action, XpAward award) {
    return _enqueue(() async {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc('main');
      final today = _todayKey();

      try {
        final snapshot = await docRef.get().timeout(const Duration(seconds: 8));
        final data =
            snapshot.exists ? (snapshot.data() ?? <String, dynamic>{}) : <String, dynamic>{};
        final rawCounters = data['dailyXp'];
        final counters = rawCounters is Map
            ? Map<String, dynamic>.from(rawCounters)
            : <String, dynamic>{};
        final todayEntry = counters[today];
        final todayCounts = todayEntry is Map
            ? Map<String, dynamic>.from(todayEntry)
            : <String, dynamic>{};
        final used = (todayCounts[action] as num?)?.toInt() ?? 0;
        if (used >= award.dailyCap) return false;

        todayCounts[action] = used + 1;
        counters[today] = todayCounts;

        final rawXp = data['xpTotal'];
        final currentXp =
            rawXp is int ? rawXp : (rawXp as num?)?.toInt() ?? 0;
        final newXp = currentXp + award.amount;
        final newLevel = UserProgress.levelForXp(newXp);

        if (snapshot.exists) {
          await docRef.update({
            'xpTotal': newXp,
            'level': newLevel,
            'dailyXp': counters,
            'lastActivity': FieldValue.serverTimestamp(),
          });
        } else {
          await docRef.set({
            'xpTotal': newXp,
            'level': newLevel,
            'streak': 1,
            'dailyXp': counters,
            'lastActivity': FieldValue.serverTimestamp(),
          });
        }

        final storedLevel = (data['level'] as num?)?.toInt() ?? 1;
        if (newLevel > storedLevel) {
          AudioService().playSfx(AudioService.levelUp);
        } else {
          AudioService().playSfx(AudioService.sparkle);
        }
        return true;
      } on TimeoutException {
        Logger.w('XP awardDaily timed out ($action)');
        return false;
      } catch (e) {
        Logger.e('XP awardDaily failed ($action)', error: e);
        return false;
      }
    });
  }

  Future<bool> awardMood(String uid) =>
      awardDaily(uid, 'mood', XPService.moodAward);

  Future<bool> awardJournal(String uid) =>
      awardDaily(uid, 'journal', XPService.journalAward);

  Future<bool> awardGarden(String uid) =>
      awardDaily(uid, 'garden', XPService.gardenAward);

  Future<bool> awardStar(String uid) =>
      awardDaily(uid, 'star', XPService.starAward);

  Future<bool> awardListen(String uid) =>
      awardDaily(uid, 'listen', XPService.listenAward);

  Future<bool> awardPlay(String uid) =>
      awardDaily(uid, 'play', XPService.playAward);

  Future<bool> awardDedicate(String uid) =>
      awardDaily(uid, 'dedicate', XPService.dedicateAward);

  Future<void> initializeProgress(String uid) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('main');

    try {
      final snapshot = await docRef.get().timeout(
            const Duration(seconds: 6),
          );
      if (!snapshot.exists) {
        await docRef.set({
          'xpTotal': 0,
          'level': 1,
          'streak': 0,
          'lastActivity': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 6));
      }
    } on TimeoutException {
      // WebChannel contended or offline — the UI already paints an
      // optimistic zero-state bar, so just let the next watchProgress
      // retry seed the doc.
      return;
    }
  }
}
