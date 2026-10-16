import 'package:everglow/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 430.0, 810.0]) {
    testWidgets('chat fits ${width}px with large text and failed actions', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var retried = false;
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ChatBubble(
                      text:
                          'A long message with enough words to wrap comfortably on a small phone.',
                      isMe: false,
                      sender: 'Demo partner',
                      timestamp: DateTime(2026, 10, 16, 12),
                    ),
                    ChatBubble(
                      text: 'Hello',
                      isMe: true,
                      sender: 'Demo sender',
                      timestamp: DateTime(2026, 10, 16, 12),
                      isFailed: true,
                      onRetry: () => retried = true,
                      onDismiss: () => dismissed = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Delete'));
      expect(retried, isTrue);
      expect(dismissed, isTrue);
      await tester.tap(find.byTooltip('Message actions').last);
      await tester.pumpAndSettle();
      expect(find.text('Copy message'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
