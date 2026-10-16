import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/utils/latest_value_writer.dart';

void main() {
  test(
    'slow saves retain only the latest pending value and await final save',
    () async {
      final gate = Completer<void>();
      final writes = <int>[];
      final writer = LatestValueWriter<int>(
        write: (value) async {
          writes.add(value);
          if (value == 1) await gate.future;
        },
        onError: (error, stack) => fail('$error'),
      );
      final done = writer.add(1);
      writer.add(2);
      writer.add(3);
      expect(writes, [1]);
      gate.complete();
      await done;
      expect(writes, [1, 3]);
      await writer.add(4);
      expect(writes, [1, 3, 4]);
    },
  );

  test(
    'disconnect drops pending work and failure does not strand the writer',
    () async {
      final gate = Completer<void>();
      final writes = <int>[];
      final errors = <Object>[];
      final writer = LatestValueWriter<int>(
        write: (value) async {
          writes.add(value);
          if (value == 1) {
            await gate.future;
            throw StateError('offline');
          }
        },
        onError: (error, stack) => errors.add(error),
      );
      final done = writer.add(1);
      writer.add(2);
      writer.clearPending();
      gate.complete();
      await done;
      await writer.add(3);
      expect(writes, [1, 3]);
      expect(errors, hasLength(1));
    },
  );
}
