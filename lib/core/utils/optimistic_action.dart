import 'dart:async';
import 'package:flutter/foundation.dart';
import 'logger.dart';

/// Core utility implementing the Optimistic UI pattern:
/// 1. User acts (triggers action)
/// 2. Render now (apply optimistic state immediately, assuming success)
/// 3. Reconcile (server confirms; or on failure, rollback to previous state)
class OptimisticAction {
  OptimisticAction._();

  /// Runs an optimistic operation.
  ///
  /// - [apply]: Synchronously called right away to update the UI (e.g. `setState` or state notifier).
  /// - [action]: The asynchronous server/network operation (e.g. Firestore write).
  /// - [rollback]: Synchronously called if [action] throws, reverting the UI to its prior state.
  /// - [onSuccess]: Optional callback invoked when the server operation succeeds.
  /// - [onError]: Optional error handler invoked when the server operation fails.
  static Future<T?> run<T>({
    required VoidCallback apply,
    required Future<T> Function() action,
    required VoidCallback rollback,
    ValueChanged<T>? onSuccess,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    // 1. Render now (assume success)
    try {
      apply();
    } catch (e, st) {
      Logger.e('Optimistic apply failed', error: e, stackTrace: st);
      return null;
    }

    // 2. Asynchronously reconcile with server
    try {
      final result = await action();
      onSuccess?.call(result);
      return result;
    } catch (error, stackTrace) {
      // 3. Rollback immediately on server failure
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

/// Tracks optimistic additions and removals over a server-synced collection
/// (e.g. watchlist IDs, favorites, bookmarks).
///
/// Handles the lag between the local action and the Firestore stream update,
/// ensuring the UI renders the intended state instantly and reconciles when
/// the server stream catches up.
class OptimisticSet<T> {
  final Set<T> _added = <T>{};
  final Set<T> _removed = <T>{};

  /// Whether there are any pending optimistic changes awaiting server confirmation.
  bool get hasPendingChanges => _added.isNotEmpty || _removed.isNotEmpty;

  /// Read-only view of pending additions.
  Set<T> get added => Set.unmodifiable(_added);

  /// Read-only view of pending removals.
  Set<T> get removed => Set.unmodifiable(_removed);

  /// Whether [item] has a pending optimistic addition.
  bool isAdded(T item) => _added.contains(item);

  /// Whether [item] has a pending optimistic removal.
  bool isRemoved(T item) => _removed.contains(item);

  /// Optimistically mark an item as added.
  void markAdded(T item) {
    _removed.remove(item);
    _added.add(item);
  }

  /// Optimistically mark an item as removed.
  void markRemoved(T item) {
    _added.remove(item);
    _removed.add(item);
  }

  /// Reverts an optimistic addition (e.g. on server error).
  void rollbackAdd(T item) {
    _added.remove(item);
  }

  /// Reverts an optimistic removal (e.g. on server error).
  void rollbackRemove(T item) {
    _removed.remove(item);
  }

  /// Clears all pending changes for [item].
  void clear(T item) {
    _added.remove(item);
    _removed.remove(item);
  }

  /// Clears all pending optimistic changes.
  void clearAll() {
    _added.clear();
    _removed.clear();
  }

  /// Checks if [item] is considered present, factoring in optimistic state
  /// against the latest [serverItems].
  bool contains(T item, Iterable<T> serverItems) {
    if (_removed.contains(item)) return false;
    if (_added.contains(item)) return true;
    return serverItems.contains(item);
  }

  /// Reconciles pending optimistic changes with fresh [serverItems].
  ///
  /// Any added item confirmed present in [serverItems] is dropped from pending.
  /// Any removed item confirmed absent from [serverItems] is dropped from pending.
  void reconcile(Iterable<T> serverItems) {
    final serverSet = serverItems is Set<T> ? serverItems : serverItems.toSet();
    _added.removeWhere((item) => serverSet.contains(item));
    _removed.removeWhere((item) => !serverSet.contains(item));
  }

  /// Applies pending additions and removals to [serverItems], returning
  /// an effective list reflecting the optimistic state.
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
