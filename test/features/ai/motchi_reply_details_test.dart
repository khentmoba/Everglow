import 'package:everglow/features/ai/domain/models/ai_conversation.dart';
import 'package:everglow/features/ai/domain/motchi_reply_details.dart';
import 'package:everglow/features/ai/presentation/widgets/motchi_reply_details_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const demo = MotchiReplyDetails(
  memories: [
    {
      'id': 'demo-clair',
      'fact': 'Clair prefers short movies',
      'subject': 'Clair',
    },
  ],
  steps: [
    {
      'tool': 'add_calendar_event',
      'status': 'done',
      'write': true,
      'title': 'Demo date',
    },
    {
      'tool': 'create_reminder',
      'status': 'failed',
      'write': true,
      'title': 'Demo snacks',
    },
  ],
);

void main() {
  testWidgets('long action receipts fit a small phone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: MotchiReplyDetailsCard(
              details: MotchiReplyDetails(
                steps: [
                  {
                    'tool': 'create_reminder',
                    'status': 'unscheduled',
                    'write': true,
                    'title':
                        'A long synthetic reminder title that should wrap rather than hide the result',
                  },
                  {
                    'tool': 'add_calendar_event',
                    'status': 'unknown',
                    'write': true,
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Saved, but not scheduled'), findsOneWidget);
    expect(find.text('Could not confirm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'receipts survive conversation and session serialization, not model invention',
    () {
      final conv = AIConversation(
        id: 'demo',
        feature: 'assistant',
        messages: [
          AIMessage(
            role: 'assistant',
            content: 'The date was saved.',
            details: demo,
          ),
        ],
      );
      final restored = AIConversation.fromJson(conv.toJson()).messages.single;
      expect(restored.details.toJson(), demo.toJson());
      expect(
        restored.toApiPayload()['content'],
        contains('add_calendar_event: done'),
      );
      expect(
        restored.toApiPayload()['content'],
        contains('create_reminder: failed'),
      );
      expect(
        AIMessage.fromJson({
          'role': 'assistant',
          'content': 'Old reply',
        }).details.isEmpty,
        isTrue,
      );
    },
  );

  test(
    'live results, Stop and disconnection preserve completed and unconfirmed work',
    () {
      final details = MotchiReplyDetails.fromResults(
        [
          {'step': demo.steps.first},
        ],
        interrupted: true,
        activeTools: ['create_reminder'],
      );
      expect(details.steps.first['status'], 'done');
      expect(details.steps.last['status'], 'unknown');
      expect(details.interrupted, isTrue);
      expect(details.needsAttention, isTrue);
    },
  );

  test('a resolved confirmation is not still shown as waiting', () {
    final details = MotchiReplyDetails.fromResults([
      {
        'step': {
          'tool': 'delete_memory',
          'status': 'waiting',
          'target': 'demo-clair',
        },
      },
      {
        'step': {
          'tool': 'delete_memory',
          'status': 'done',
          'target': 'demo-clair',
        },
      },
    ]);
    expect(details.steps.length, 1);
    expect(details.steps.single['status'], 'done');
    expect(details.needsAttention, isFalse);
  });

  test(
    'read-only, waiting and unscheduled results do not claim everything was saved',
    () {
      expect(
        const MotchiReplyDetails(
          steps: [
            {'tool': 'search_movies', 'status': 'done', 'write': false},
          ],
        ).summary,
        contains('nothing saved yet'),
      );
      expect(
        const MotchiReplyDetails(
          steps: [
            {'status': 'waiting'},
          ],
        ).summary,
        contains('Waiting'),
      );
      expect(
        const MotchiReplyDetails(
          steps: [
            {'status': 'unscheduled'},
          ],
        ).summary,
        contains('attention'),
      );
    },
  );

  test(
    'citation syntax stays hidden even across streaming token boundaries',
    () {
      const marker = '[[memory:demo-clair]]';
      for (var i = 2; i <= marker.length; i++) {
        expect(
          MotchiReplyDetails.visibleText(
            'A short movie. ${marker.substring(0, i)}',
          ),
          'A short movie. ',
        );
      }
      expect(
        MotchiReplyDetails.visibleText('Hello [[other]]'),
        'Hello [[other]]',
      );
      expect(
        MotchiReplyDetails.owner({'subject': 'Clair', 'source': 'khentsgdz'}),
        'Clair',
      );
      expect(
        MotchiReplyDetails.owner({'subject': 'Khent and Clair'}),
        'Both of you',
      );
      expect(
        MotchiReplyDetails.owner({'source': 'clairjassen'}),
        'Owner not specified',
      );
    },
  );

  for (final width in [430.0, 800.0]) {
    testWidgets(
      'memory inspection, correction and honest receipts at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? correction;
        var openedBook = false;
        var continued = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MotchiReplyDetailsCard(
                  details: demo,
                  onCorrectMemory: (text) => correction = text,
                  onOpenMemoryBook: () => openedBook = true,
                  onContinue: () => continued = true,
                ),
              ),
            ),
          ),
        );
        expect(find.text('Some steps still need attention.'), findsOneWidget);
        expect(find.textContaining('Add calendar event'), findsOneWidget);
        expect(find.textContaining('Create reminder'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Did not complete'), findsOneWidget);
        await tester.tap(find.text('Open Memory Book'));
        expect(openedBook, isTrue);
        await tester.tap(find.text('Help finish unfinished steps'));
        expect(continued, isTrue);
        await tester.tap(
          find.textContaining('Clair · Clair prefers short movies'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Memory behind this reply'), findsOneWidget);
        await tester.enterText(
          find.byType(TextField),
          'Clair prefers short comedies',
        );
        await tester.tap(find.text('Ask Motchi to correct it'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 350));
        expect(correction, contains('memory_id "demo-clair"'));
        expect(correction, contains('Clair prefers short comedies'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a read that did not complete stays visible without raising an alarm',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // The anime sidechat: web_search landed, one page read landed, one
      // page read did not. The reply itself answered fine.
      final details = MotchiReplyDetails.fromResults([
        {
          'tool': 'web_search',
          'step': {
            'tool': 'web_search',
            'status': 'done',
            'write': false,
            'title': 'Mushoku Tensei Season 3 announcement',
          },
        },
        {
          'tool': 'read_web_page',
          'step': {
            'tool': 'read_web_page',
            'status': 'done',
            'write': false,
            'title': 'fandom.com',
          },
        },
        {
          'tool': 'read_web_page',
          'step': {
            'tool': 'read_web_page',
            'status': 'failed',
            'write': false,
            'title': 'facebook.com',
          },
        },
      ]);
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MotchiReplyDetailsCard(
                details: details,
                onContinue: () => continued = true,
              ),
            ),
          ),
        ),
      );
      expect(details.summary, 'Information found — nothing saved yet.');
      expect(details.needsAttention, isFalse);
      expect(
        find.textContaining('Some steps still need attention'),
        findsNothing,
      );
      // The failed read is still reported — trust means showing it.
      expect(find.textContaining('Read web page'), findsNWidgets(2));
      expect(find.text('Done'), findsNWidgets(2));
      expect(find.textContaining('fandom.com'), findsOneWidget);
      expect(find.textContaining('Did not complete'), findsOneWidget);
      expect(find.textContaining('facebook.com'), findsOneWidget);
      expect(find.text('Help finish unfinished steps'), findsNothing);
      expect(continued, isFalse);
    },
  );

  testWidgets(
    'interrupted web searches with only reads do not ask to finish unfinished steps',
    (tester) async {
      final details = MotchiReplyDetails.fromResults([
        {
          'tool': 'web_search',
          'step': {
            'tool': 'web_search',
            'status': 'done',
            'write': false,
            'title': 'VCT Champions 2026',
          },
        },
        {
          'tool': 'read_web_page',
          'step': {
            'tool': 'read_web_page',
            'status': 'done',
            'write': false,
            'title': 'vlr.gg',
          },
        },
      ], interrupted: true);
      expect(details.interrupted, isTrue);
      expect(details.needsAttention, isFalse);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MotchiReplyDetailsCard(
                details: details,
                onContinue: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Help finish unfinished steps'), findsNothing);
    },
  );

  testWidgets('a write that did not complete still demands attention', (
    tester,
  ) async {
    final details = MotchiReplyDetails.fromResults([
      {
        'tool': 'add_calendar_event',
        'step': {
          'tool': 'add_calendar_event',
          'status': 'failed',
          'write': true,
          'title': 'Date night',
        },
      },
    ]);
    expect(details.summary, 'Some steps still need attention.');
    expect(details.needsAttention, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MotchiReplyDetailsCard(details: details)),
      ),
    );
    expect(find.text('Some steps still need attention.'), findsOneWidget);
    expect(find.textContaining('Add calendar event'), findsOneWidget);
    expect(find.text('Did not complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
