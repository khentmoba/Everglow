import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/chat/domain/models/chat_message.dart';

void main() {
  group('ChatMessage optimistic flags', () {
    test('defaults isOptimistic and isFailed to false', () {
      final msg = ChatMessage(
        id: 'msg_1',
        sender: 'khentsgdz',
        senderUid: 'uid_1',
        text: 'hello',
        timestamp: DateTime(2026, 9, 21),
      );

      expect(msg.isOptimistic, isFalse);
      expect(msg.isFailed, isFalse);
    });

    test('copyWith updates isOptimistic and isFailed properly', () {
      final msg = ChatMessage(
        id: 'temp_1',
        sender: 'khentsgdz',
        senderUid: 'uid_1',
        text: 'sending now',
        timestamp: DateTime(2026, 9, 21),
        isOptimistic: true,
      );

      expect(msg.isOptimistic, isTrue);
      expect(msg.isFailed, isFalse);

      final failed = msg.copyWith(isFailed: true, isOptimistic: false);
      expect(failed.isOptimistic, isFalse);
      expect(failed.isFailed, isTrue);
      expect(failed.text, equals('sending now'));
      expect(failed.sender, equals('khentsgdz'));

      final confirmed = failed.copyWith(id: 'firestore_doc_1', isFailed: false);
      expect(confirmed.id, equals('firestore_doc_1'));
      expect(confirmed.isFailed, isFalse);
    });

    test(
      '1-to-1 matching reconciles only one duplicate message per confirmation',
      () {
        final now = DateTime.now();
        final optimistic1 = ChatMessage(
          id: 'opt_1',
          sender: 'clair',
          senderUid: 'u1',
          text: 'love you!',
          timestamp: now,
          isOptimistic: true,
        );
        final optimistic2 = ChatMessage(
          id: 'opt_2',
          sender: 'clair',
          senderUid: 'u1',
          text: 'love you!',
          timestamp: now.add(const Duration(seconds: 1)),
          isOptimistic: true,
        );

        final optimisticList = [optimistic1, optimistic2];

        // First confirmation arrives
        final server1 = ChatMessage(
          id: 'srv_1',
          sender: 'clair',
          senderUid: 'u1',
          text: 'love you!',
          timestamp: now,
        );
        final serverMessages = [server1];

        final matchedServerIds = <String>{};
        final remainingOptimistic = <ChatMessage>[];

        for (final opt in optimisticList) {
          if (opt.isFailed) {
            remainingOptimistic.add(opt);
            continue;
          }
          var matched = false;
          for (final srv in serverMessages) {
            if (matchedServerIds.contains(srv.id)) continue;
            if (srv.sender == opt.sender &&
                srv.text == opt.text &&
                srv.timestamp.difference(opt.timestamp).abs().inSeconds < 45) {
              matchedServerIds.add(srv.id);
              matched = true;
              break;
            }
          }
          if (!matched) {
            remainingOptimistic.add(opt);
          }
        }

        // Exactly ONE was reconciled, the second optimistic message is preserved!
        expect(remainingOptimistic.length, equals(1));
        expect(remainingOptimistic.first.id, equals('opt_2'));
      },
    );
  });
}
