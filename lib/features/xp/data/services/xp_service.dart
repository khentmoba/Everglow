import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  XPService._internal();

  static const XpAward moodAward = XpAward(20, 1);
  static const XpAward journalAward = XpAward(30, 2);
  static const XpAward gardenAward = XpAward(10, 1);
  static const XpAward starAward = XpAward(15, 3);
  static const XpAward listenAward = XpAward(2, 30);
  static const XpAward playAward = XpAward(3, 20);
  static const XpAward dedicateAward = XpAward(15, 5);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

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

  Future<void> _addUncapped(String uid, int amount) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('main');

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, {
          'xpTotal': amount,
          'level': UserProgress.levelForXp(amount),
          'streak': 1,
          'lastActivity': FieldValue.serverTimestamp(),
        });
      } else {
        final rawXp = snapshot.data()!['xpTotal'];
        final currentXp =
            rawXp is int ? rawXp : (rawXp as num?)?.toInt() ?? 0;
        final newXp = currentXp + amount;
        final newLevel = UserProgress.levelForXp(newXp);

        transaction.update(docRef, {
          'xpTotal': newXp,
          'level': newLevel,
          'lastActivity': FieldValue.serverTimestamp(),
        });

        final storedLevel = (snapshot.data()!['level'] as num?)?.toInt() ?? 1;
        if (newLevel > storedLevel) {
          AudioService().playSfx(AudioService.levelUp);
        } else {
          AudioService().playSfx(AudioService.sparkle);
        }
      }
    });
  }

  Future<bool> awardDaily(String uid, String action, XpAward award) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('main');
    final today = _todayKey();

    try {
      var granted = false;
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final data =
            snapshot.exists ? snapshot.data()! : <String, dynamic>{};
        final rawCounters = data['dailyXp'];
        final counters = rawCounters is Map
            ? Map<String, dynamic>.from(rawCounters)
            : <String, dynamic>{};
        final todayEntry = counters[today];
        final todayCounts = todayEntry is Map
            ? Map<String, dynamic>.from(todayEntry)
            : <String, dynamic>{};
        final used = (todayCounts[action] as num?)?.toInt() ?? 0;
        if (used >= award.dailyCap) return;

        todayCounts[action] = used + 1;
        counters[today] = todayCounts;

        final rawXp = data['xpTotal'];
        final currentXp =
            rawXp is int ? rawXp : (rawXp as num?)?.toInt() ?? 0;
        final newXp = currentXp + award.amount;
        final newLevel = UserProgress.levelForXp(newXp);

        if (snapshot.exists) {
          transaction.update(docRef, {
            'xpTotal': newXp,
            'level': newLevel,
            'dailyXp': counters,
            'lastActivity': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(docRef, {
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
        granted = true;
      });
      return granted;
    } catch (e) {
      Logger.e('XP awardDaily failed ($action)', error: e);
      return false;
    }
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
