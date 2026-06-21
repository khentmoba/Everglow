import 'dart:async';

import 'package:flutter/foundation.dart';

/// Wraps a Firestore snapshot stream with a bounded timeout so
/// StreamBuilders never sit in `ConnectionState.waiting` forever.
///
/// On web, Firestore listeners can hang after route navigation or
/// backgrounding. This ensures the stream emits an error/close within
/// [duration] if no data arrives, giving the UI a chance to show a
/// retry state instead of an infinite spinner.
Stream<T> withFirestoreTimeout<T>(
  Stream<T> stream, {
  Duration duration = const Duration(seconds: 5),
  String? label,
}) {
  return stream.timeout(
    duration,
    onTimeout: (sink) {
      if (kDebugMode) {
        debugPrint(
          '[Firestore stream timeout] ${label ?? 'stream'} '
          'after ${duration.inSeconds}s',
        );
      }
      sink.close();
    },
  );
}
