import 'package:flutter/material.dart';

import '../../../core/utils/firestore_stream_utils.dart';
import 'everglow_error_state.dart';
import 'everglow_skeleton.dart';

/// The ONE way to show a live Firestore list.
///
/// Replaces copy-pasted `StreamBuilder` + `hasError` + `waiting` blocks
/// (15+ screens). Every list shows the same loading spinner and the
/// same error card, so Clair sees one consistent app and agents learn
/// one pattern.
///
/// ```dart
/// EverglowStreamView<List<Trip>>(
///   stream: service.watchTrips(),
///   streamLabel: 'travel-trips',
///   isEmpty: (trips) => trips.isEmpty,
///   emptyView: EverglowEmptyState(...),
///   builder: (context, trips) => ListView(...),
/// )
/// ```
class EverglowStreamView<T> extends StatelessWidget {
  /// Live Firestore stream (already wrapped with a first-event timeout).
  final Stream<T> stream;

  /// Label used in debug logs when the first snapshot hangs.
  final String? streamLabel;

  /// Builds the list once data arrives and [isEmpty] is false.
  final Widget Function(BuildContext context, T data) builder;

  /// Returns true when `data` should show [emptyView] instead of [builder].
  /// Pass `(list) => list.isEmpty` for lists.
  final bool Function(T data)? isEmpty;

  /// Shown when [isEmpty] returns true. Required when [isEmpty] is given.
  final Widget? emptyView;

  /// Shown while waiting for the first snapshot.
  /// Defaults to [EverglowLoadingState].
  final Widget? loadingView;

  /// Optional message under the default loading spinner.
  final String? loadingMessage;

  /// Message for the default error card.
  final String errorMessage;

  /// Icon for the default error card.
  final IconData errorIcon;

  /// Retry callback for the default error card. Usually `() => setState(() {})`.
  final VoidCallback? onRetry;

  const EverglowStreamView({
    super.key,
    required this.stream,
    required this.builder,
    this.streamLabel,
    this.isEmpty,
    this.emptyView,
    this.loadingView,
    this.loadingMessage,
    this.errorMessage = 'Could not load',
    this.errorIcon = Icons.cloud_off_outlined,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: withFirestoreTimeout(stream, label: streamLabel ?? 'stream'),
      builder: (context, snap) {
        if (snap.hasError) {
          return EverglowErrorState(
            message: errorMessage,
            onRetry: onRetry,
            icon: errorIcon,
          );
        }
        if (!snap.hasData) {
          return loadingView ??
              EverglowLoadingState(message: loadingMessage);
        }
        final data = snap.data as T;
        if (isEmpty?.call(data) == true) {
          return emptyView ?? const SizedBox.shrink();
        }
        return builder(context, data);
      },
    );
  }
}
