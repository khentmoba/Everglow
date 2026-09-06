import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Wraps a Firestore snapshot stream with a bounded budget for the *first*
/// event so StreamBuilders never sit in `ConnectionState.waiting` forever.
///
/// On web, Firestore listeners can hang after route navigation or
/// backgrounding. Without a budget the UI shows an infinite spinner; with
/// this wrapper it gets an error/close it can render as a retry state.
///
/// The budget only guards the initial emission. Firestore snapshot
/// streams are long-lived push channels that legitimately emit nothing
/// for minutes at a time; once the first snapshot is delivered, the
/// stream is passed through untouched until the source closes or errors.
///
/// Cold starts (new WebChannel + auth token + query) routinely exceed a
/// few seconds on slow networks, and every dashboard preview attaches at
/// the same moment — so a single-shot budget flipped ALL of them to the
/// error state at once. Pass [resubscribe] (a factory for a fresh query
/// stream) to let the wrapper silently re-attach with [retryDelay]
/// backoff before surfacing an error, up to [maxAttempts] total attempts.
/// Without [resubscribe] the behavior is the legacy one: a first-event
/// timeout closes the stream, and a first-event error is forwarded.
Stream<T> withFirestoreTimeout<T>(
  Stream<T> stream, {
  Duration duration = const Duration(seconds: 5),
  String? label,
  Stream<T> Function()? resubscribe,
  int maxAttempts = 2,
  Duration retryDelay = const Duration(seconds: 2),
}) {
  final guard = _FirstEventGuard<T>(
    firstStream: stream,
    duration: duration,
    name: label ?? 'stream',
    factory: resubscribe,
    maxAttempts: maxAttempts,
    retryDelay: retryDelay,
  );
  return guard.output;
}

/// State machine behind [withFirestoreTimeout]. A tiny class (instead of
/// closures) so the mutually-recursive attach/retry/finish steps compile:
/// Dart local functions cannot forward-reference each other.
class _FirstEventGuard<T> {
  _FirstEventGuard({
    required Stream<T> firstStream,
    required this.duration,
    required this.name,
    required this.factory,
    required this.maxAttempts,
    required this.retryDelay,
  }) : _pendingSource = firstStream {
    _controller = StreamController<T>(
      onListen: _onListen,
      onCancel: _onCancel,
    );
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
      // The current listener is wedged (or just too slow): drop it so
      // it can't deliver a stale first event later.
      _cancelSubscription();
      if (factory != null && _attempt < maxAttempts) {
        // ignore: avoid_print
        print(
          '[Firestore] $name no first event after ${duration.inSeconds}s '
          '(attempt $_attempt/$maxAttempts) — re-attaching…',
        );
        _scheduleReattach();
      } else if (factory != null) {
        _finishError(
          TimeoutException(
            'No data from $name after $maxAttempts attempts',
            retryDelay,
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

  /// Re-attaches via [factory] after [retryDelay], unless the first event
  /// arrived or the guard settled meanwhile. A factory that throws
  /// synchronously settles the guard with that error.
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
          // Pre-first-event failure: transient blips (and token-refresh
          // races) deserve a silent re-attach before the UI gives up.
          _cancelSubscription();
          if (factory != null && _attempt < maxAttempts) {
            // ignore: avoid_print
            print(
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
          // Source closed without data (or the budget path already
          // re-attached and this is the stale subscription draining).
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
      // The source threw synchronously on listen (e.g. an already-
      // listened single-subscription stream or a misconfigured SDK).
      _finishError(error, stackTrace);
    }
  }

  void _finishError(Object error, StackTrace stackTrace) {
    if (_settled) return;
    _settled = true;
    _cancelTimers();
    _cancelSubscription();
    // Raw print: Logger is silent in release builds, and this line is
    // the only trace distinguishing a timeout from permission-denied
    // from offline in a production bug report.
    // ignore: avoid_print
    print('[Firestore] $name failed: ${_shortError(error)}');
    _controller.addError(error, stackTrace);
  }
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

/// Human-readable cause for a Firestore stream failure, for retry rows.
///
/// The dashboard previews historically showed one generic line for every
/// failure mode, which made "could not load" reports undiagnosable.
/// Returns a short noun phrase that reads naturally as
/// `'<hint> — tap here to retry.'`.
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
