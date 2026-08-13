import 'dart:async';

import 'package:flutter/foundation.dart';

/// Wraps a Firestore snapshot stream with a bounded timeout so
/// StreamBuilders never sit in `ConnectionState.waiting` forever.
///
/// On web, Firestore listeners can hang after route navigation or
/// backgrounding. This ensures the stream emits an error/close within
/// [duration] if the *first* snapshot never arrives, giving the UI a
/// chance to show a retry state instead of an infinite spinner.
///
/// The timeout only guards the initial emission. Firestore snapshot
/// streams are long-lived push channels that legitimately emit nothing
/// for minutes at a time; applying the timeout for the whole lifetime
/// silently killed chat, presence, and WebRTC signaling after a quiet
/// period. Once the first snapshot is delivered, the stream is passed
/// through untouched until the source closes or errors.
Stream<T> withFirestoreTimeout<T>(
  Stream<T> stream, {
  Duration duration = const Duration(seconds: 5),
  String? label,
}) {
  late StreamController<T> controller;
  StreamSubscription<T>? subscription;
  Timer? initialTimer;
  var receivedFirst = false;

  controller = StreamController<T>(
    onListen: () {
      initialTimer = Timer(duration, () {
        if (receivedFirst) return;
        if (kDebugMode) {
          debugPrint(
            '[Firestore stream timeout] ${label ?? 'stream'} '
            'no first event after ${duration.inSeconds}s',
          );
        }
        controller.close();
      });

      subscription = stream.listen(
        (event) {
          if (!receivedFirst) {
            receivedFirst = true;
            initialTimer?.cancel();
          }
          if (!controller.isClosed) controller.add(event);
        },
        onError: (Object error, StackTrace stackTrace) {
          initialTimer?.cancel();
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          initialTimer?.cancel();
          if (!controller.isClosed) controller.close();
        },
      );
    },
    onCancel: () async {
      initialTimer?.cancel();
      await subscription?.cancel();
    },
  );

  return controller.stream;
}
