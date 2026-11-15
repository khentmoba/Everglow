import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'logger.dart';

Stream<T> withFirestoreTimeout<T>(
  Stream<T> stream, {
  Duration duration = const Duration(seconds: 5),
  String? label,
  Stream<T> Function()? resubscribe,
  int maxAttempts = 2,
  Duration retryDelay = const Duration(seconds: 2),
}) {
  final effectiveDuration = kIsWeb && duration < const Duration(seconds: 25)
      ? const Duration(seconds: 25)
      : duration;
  final effectiveAttempts = kIsWeb && maxAttempts < 3 ? 3 : maxAttempts;

  final guard = _FirstEventGuard<T>(
    firstStream: stream,
    duration: effectiveDuration,
    name: label ?? 'stream',
    factory: resubscribe,
    maxAttempts: effectiveAttempts,
    retryDelay: retryDelay,
  );
  return guard.output;
}

class _FirstEventGuard<T> {
  _FirstEventGuard({
    required Stream<T> firstStream,
    required this.duration,
    required this.name,
    required this.factory,
    required this.maxAttempts,
    required this.retryDelay,
  }) : _pendingSource = firstStream {
    _controller = StreamController<T>(onListen: _onListen, onCancel: _onCancel);
  }

  final Duration duration;
  final String name;
  final Stream<T> Function()? factory;
  final int maxAttempts;
  final Duration retryDelay;

  late final StreamController<T> _controller;
  Stream<T>? _pendingSource;
  StreamSubscription<T>? _subscription;
  Timer? _budgetTimer;
  Timer? _backoffTimer;
  var _attempt = 0;
  var _receivedFirst = false;
  var _settled = false;

  Stream<T> get output => _controller.stream;

  void _onListen() {
    final first = _pendingSource;
    _pendingSource = null;
    if (first != null) _attach(first);
  }

  Future<void> _onCancel() async {
    _settled = true;
    _cancelTimers();
    await _subscription?.cancel();
    _subscription = null;
  }

  void _cancelTimers() {
    _budgetTimer?.cancel();
    _budgetTimer = null;
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  void _cancelSubscription() {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) unawaited(sub.cancel());
  }

  void _armBudgetTimer() {
    _budgetTimer?.cancel();
    _budgetTimer = Timer(duration, () {
      if (_receivedFirst || _settled) return;
      _cancelSubscription();
      if (factory != null && _attempt < maxAttempts) {
        Logger.w(
          '[Firestore] $name no first event after ${duration.inSeconds}s '
          '(attempt $_attempt/$maxAttempts) — re-attaching…',
        );
        _scheduleReattach();
      } else if (factory != null) {
        _finishError(
          TimeoutException(
            'No data from $name after $maxAttempts attempts',
            duration * maxAttempts,
          ),
          StackTrace.current,
        );
      } else {
        if (kDebugMode) {
          debugPrint(
            '[Firestore stream timeout] $name '
            'no first event after ${duration.inSeconds}s',
          );
        }
        _settled = true;
        _cancelTimers();
        _controller.close();
      }
    });
  }

  void _scheduleReattach() {
    _backoffTimer?.cancel();
    _backoffTimer = Timer(retryDelay, () {
      if (_receivedFirst || _settled) return;
      final make = factory;
      if (make == null) return;
      Stream<T> next;
      try {
        next = make();
      } catch (error, stackTrace) {
        _finishError(error, stackTrace);
        return;
      }
      _attach(next);
    });
  }

  void _attach(Stream<T> source) {
    _attempt++;
    _armBudgetTimer();
    try {
      _subscription = source.listen(
        (event) {
          if (!_receivedFirst) {
            _receivedFirst = true;
            _budgetTimer?.cancel();
          }
          if (!_settled) _controller.add(event);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_receivedFirst) {
            _budgetTimer?.cancel();
            if (!_settled) _controller.addError(error, stackTrace);
            return;
          }
          _cancelSubscription();
          if (_isPermanent(error)) {
            _finishError(error, stackTrace);
            return;
          }
          if (factory != null && _attempt < maxAttempts) {
            Logger.w(
              '[Firestore] $name attempt $_attempt/$maxAttempts failed '
              'before first event (${_shortError(error)}) — re-attaching…',
            );
            _scheduleReattach();
          } else {
            _finishError(error, stackTrace);
          }
        },
        onDone: () {
          if (_receivedFirst) {
            _budgetTimer?.cancel();
            if (!_settled) {
              _settled = true;
              _cancelTimers();
              _controller.close();
            }
            return;
          }
          _cancelSubscription();
          if (factory != null && _attempt < maxAttempts && !_settled) {
            _scheduleReattach();
          } else if (!_settled) {
            _settled = true;
            _cancelTimers();
            _controller.close();
          }
        },
      );
    } catch (error, stackTrace) {
      _finishError(error, stackTrace);
    }
  }

  void _finishError(Object error, StackTrace stackTrace) {
    if (_settled) return;
    _settled = true;
    _cancelTimers();
    _cancelSubscription();
    Logger.e('[Firestore] $name failed: ${_shortError(error)}');
    _controller.addError(error, stackTrace);
  }
}

bool _isPermanent(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'failed-precondition':
      case 'permission-denied':
      case 'unauthenticated':
      case 'invalid-argument':
      case 'not-found':
        return true;
    }
  }
  return false;
}

String _shortError(Object error) {
  if (error is FirebaseException) {
    final msg = error.message ?? '';
    final short = msg.length > 120 ? '${msg.substring(0, 120)}…' : msg;
    return '${error.code}${short.isEmpty ? '' : ' ($short)'}';
  }
  final s = error.toString();
  return s.length > 160 ? '${s.substring(0, 160)}…' : s;
}

String firestoreErrorHint(Object? error) {
  if (error == null) return 'Could not load';
  if (error is TimeoutException) return 'Timed out';
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Access denied — try logging in again';
      case 'unauthenticated':
        return 'Session expired — log in again';
      case 'unavailable':
        return 'Network hiccup';
      case 'deadline-exceeded':
        return 'Timed out';
      case 'failed-precondition':
        return 'App needs an update';
      case 'cancelled':
        return 'Interrupted';
      case 'resource-exhausted':
        return 'Busy — try again in a bit';
    }
  }
  final msg = error.toString().toLowerCase();
  if (msg.contains('socketexception') ||
      msg.contains('network is unreachable') ||
      msg.contains('host lookup') ||
      msg.contains('connection refused') ||
      msg.contains('connection reset') ||
      msg.contains('failed host lookup')) {
    return 'You may be offline';
  }
  if (msg.contains('permission-denied') || msg.contains('permission denied')) {
    return 'Access denied — try logging in again';
  }
  if (msg.contains('timed out') || msg.contains('timeoutexception')) {
    return 'Timed out';
  }
  return 'Could not load';
}

Future<T> withGetTimeout<T>(
  Future<T> read, {
  Duration duration = const Duration(seconds: 10),
  String? label,
}) {
  final effective = kIsWeb && duration < const Duration(seconds: 25)
      ? const Duration(seconds: 25)
      : duration;
  return read.timeout(
    effective,
    onTimeout: () {
      Logger.w(
        '[GetTimeout] ${label ?? 'firestore read'} '
        'timed out after ${effective.inSeconds}s',
      );
      throw TimeoutException(
        'Firestore read timed out after ${effective.inSeconds}s',
        effective,
      );
    },
  );
}

Future<DocumentSnapshot<T>> getDocFast<T>(
  DocumentReference<T> ref, {
  Duration duration = const Duration(seconds: 10),
  String? label,
}) async {
  try {
    final cached = await ref.get(const GetOptions(source: Source.cache));
    if (cached.exists) return cached;
  } catch (e) {
    Logger.d('getDocFast cache miss for ${label ?? 'doc'}: $e');
  }
  return withGetTimeout(ref.get(), duration: duration, label: label);
}

Future<QuerySnapshot<T>> getQueryFast<T>(
  Query<T> query, {
  Duration duration = const Duration(seconds: 10),
  String? label,
}) async {
  try {
    final cached = await query.get(const GetOptions(source: Source.cache));
    if (cached.docs.isNotEmpty) return cached;
  } catch (e) {
    Logger.d('getQueryFast cache miss for ${label ?? 'query'}: $e');
  }
  return withGetTimeout(query.get(), duration: duration, label: label);
}
