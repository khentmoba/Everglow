import 'dart:async';
import 'package:flutter/foundation.dart';
import 'logger.dart';

class OptimisticAction {
  OptimisticAction._();

  static Future<T?> run<T>({
    required VoidCallback apply,
    required Future<T> Function() action,
    required VoidCallback rollback,
    ValueChanged<T>? onSuccess,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      apply();
    } catch (e, st) {
      Logger.e('Optimistic apply failed', error: e, stackTrace: st);
      return null;
    }

    try {
      final result = await action();
      onSuccess?.call(result);
      return result;
    } catch (error, stackTrace) {
      try {
        rollback();
      } catch (rollbackError, rollbackSt) {
        Logger.e(
          'Optimistic rollback failed',
          error: rollbackError,
          stackTrace: rollbackSt,
        );
      }

      if (onError != null) {
        onError(error, stackTrace);
      } else {
        Logger.e(
          'Optimistic action failed and rolled back',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return null;
    }
  }
}

class OptimisticSet<T> {
  final Set<T> _added = <T>{};
  final Set<T> _removed = <T>{};

  bool get hasPendingChanges => _added.isNotEmpty || _removed.isNotEmpty;

  Set<T> get added => Set.unmodifiable(_added);

  Set<T> get removed => Set.unmodifiable(_removed);

  bool isAdded(T item) => _added.contains(item);

  bool isRemoved(T item) => _removed.contains(item);

  void markAdded(T item) {
    _removed.remove(item);
    _added.add(item);
  }

  void markRemoved(T item) {
    _added.remove(item);
    _removed.add(item);
  }

  void rollbackAdd(T item) {
    _added.remove(item);
  }

  void rollbackRemove(T item) {
    _removed.remove(item);
  }

  void clear(T item) {
    _added.remove(item);
    _removed.remove(item);
  }

  void clearAll() {
    _added.clear();
    _removed.clear();
  }

  bool contains(T item, Iterable<T> serverItems) {
    if (_removed.contains(item)) return false;
    if (_added.contains(item)) return true;
    return serverItems.contains(item);
  }

  void reconcile(Iterable<T> serverItems) {
    final serverSet = serverItems is Set<T> ? serverItems : serverItems.toSet();
    _added.removeWhere((item) => serverSet.contains(item));
    _removed.removeWhere((item) => !serverSet.contains(item));
  }

  List<T> applyTo(Iterable<T> serverItems) {
    final result = <T>[];
    for (final item in serverItems) {
      if (!_removed.contains(item)) {
        result.add(item);
      }
    }
    for (final item in _added) {
      if (!result.contains(item)) {
        result.add(item);
      }
    }
    return result;
  }
}
