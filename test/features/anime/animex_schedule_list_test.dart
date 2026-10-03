import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/anime/data/models/animex_models.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_schedule_list.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_schedule_page.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

final _now = DateTime(2026, 8, 17, 14); // Monday, device-local time.

MediaItem _media(
  String title, {
  int? anilistId,
  int malId = 0,
  String source = 'jikan',
}) {
  return MediaItem(
    id: '',
    tmdbId: malId,
    anilistId: anilistId,
    title: title,
    mediaType: 'tv',
    posterPath: '',
    status: 'to-watch',
    isAnime: true,
    addedAt: _now,
    source: source,
  );
}

AnimexScheduleEntry _entry(MediaItem media, {DateTime? at}) =>
    AnimexScheduleEntry(
      media: media,
      episode: 4,
      airingAt: at ?? DateTime(2026, 8, 17, 10),
    );

class _LibraryController extends AnimeXController {
  List<MediaItem> items;
  bool loading = false;

  _LibraryController([this.items = const []]);

  @override
  List<MediaItem> get library => List.unmodifiable(items);

  @override
  bool get libraryLoading => loading;

  void replaceLibrary(List<MediaItem> next) {
    items = next;
    notifyListeners();
  }
}

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  group('schedule identity', () {
    test('prefers matching AniList IDs even if the MAL IDs differ', () {
      final media = _media('Schedule', anilistId: 900, malId: 100);
      expect(
        animexScheduleIsInLibrary(media, [
          _media('Saved', anilistId: 900, malId: 200),
        ]),
        isTrue,
      );
      expect(
        animexScheduleIsInLibrary(media, [
          _media('Saved', anilistId: 901, malId: 100),
        ]),
        isFalse,
      );
    });

    test('uses positive MAL IDs as fallback only for Jikan items', () {
      final media = _media('Schedule', anilistId: 900, malId: 100);
      expect(
        animexScheduleIsInLibrary(media, [_media('Saved', malId: 100)]),
        isTrue,
      );
      expect(
        animexScheduleIsInLibrary(_media('Schedule', malId: 100), [
          _media('Saved', anilistId: 900, malId: 100),
        ]),
        isTrue,
      );
      expect(
        animexScheduleIsInLibrary(media, [
          _media('TMDB', malId: 100, source: 'tmdb'),
        ]),
        isFalse,
      );
      expect(
        animexScheduleIsInLibrary(_media('TMDB', malId: 100, source: 'tmdb'), [
          _media('Saved', malId: 100),
        ]),
        isFalse,
      );
      expect(
        animexScheduleIsInLibrary(_media('Unknown'), [_media('Unknown')]),
        isFalse,
      );
    });

    test('never equates an AniList ID with a MAL ID or a title', () {
      expect(
        animexScheduleIsInLibrary(
          _media('Same title', anilistId: 100, malId: 200),
          [_media('Same title', malId: 100)],
        ),
        isFalse,
      );
      expect(
        animexScheduleIsInLibrary(_media('Same title', anilistId: 100), [
          _media('Same title', anilistId: 101),
        ]),
        isFalse,
      );
    });
  });

  test(
    'airing labels compare instants but use device-local calendar dates',
    () {
      expect(
        animexAiringLabel(DateTime(2026, 8, 17, 10).toUtc(), _now),
        'Aired today',
      );
      expect(animexAiringLabel(_now, _now), 'Aired today');
      expect(animexAiringLabel(DateTime(2026, 8, 17, 15), _now), 'Airs today');
      expect(
        animexAiringLabel(DateTime(2026, 8, 17, 19).toUtc(), _now),
        'Airs tonight',
      );
      expect(animexAiringLabel(DateTime(2026, 8, 16, 23, 59), _now), 'Aired');
      expect(animexAiringLabel(DateTime(2026, 8, 18), _now), 'Airs');
    },
  );

  testWidgets(
    'personal view is live, all view highlights matches, no bell promise',
    (tester) async {
      final saved = _media('Saved show', anilistId: 100, malId: 200);
      final other = _media('Other show', anilistId: 200, malId: 300);
      final controller = _LibraryController([saved]);
      addTearDown(controller.dispose);
      final calls = <int>[];
      await tester.pumpWidget(
        _app(
          AnimeXSchedulePage(
            controller: controller,
            now: () => _now,
            loadSchedule: (day) async {
              calls.add(day);
              return [
                _entry(saved),
                _entry(other, at: DateTime(2026, 8, 17, 19)),
              ];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, [0]);
      expect(find.text('New episodes from your list'), findsOneWidget);
      expect(find.text('Saved show'), findsOneWidget);
      expect(find.text('Other show'), findsNothing);
      expect(find.text('MY LIST'), findsOneWidget);
      expect(find.textContaining('Aired today'), findsOneWidget);
      expect(find.textContaining('local time'), findsWidgets);
      expect(
        find.textContaining('aired does not mean playable'),
        findsOneWidget,
      );
      expect(find.byTooltip('Notify me'), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);

      await tester.tap(find.text('All anime'));
      await tester.pumpAndSettle();
      expect(find.text('Other show'), findsOneWidget);
      expect(find.textContaining('Airs tonight'), findsOneWidget);
      expect(find.text('MY LIST'), findsOneWidget);
      expect(calls, [
        0,
      ]); // View changes reuse public schedule, not personal matches.

      controller.replaceLibrary([other]); // E.g. add/remove or profile switch.
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'My List'));
      await tester.pumpAndSettle();
      expect(find.text('Saved show'), findsNothing);
      expect(find.text('Other show'), findsOneWidget);
      await tester.tap(find.text('Other show'));
      await tester.pump();
      expect(controller.watchItem, same(other));
      expect(controller.watchEpisode, isNot(4)); // No EP 4 playback promise.

      controller.replaceLibrary([]);
      await tester.pump();
      expect(find.text('Other show'), findsNothing);
      expect(find.textContaining('Add anime to My List'), findsOneWidget);
    },
  );

  testWidgets('stale day results and errors cannot replace the latest day', (
    tester,
  ) async {
    final controller = _LibraryController();
    addTearDown(controller.dispose);
    final requests = <int, Completer<List<AnimexScheduleEntry>>>{};
    await tester.pumpWidget(
      _app(
        AnimeXSchedulePage(
          controller: controller,
          now: () => _now,
          loadSchedule: (day) =>
              (requests[day] = Completer<List<AnimexScheduleEntry>>()).future,
        ),
      ),
    );
    await tester.tap(find.text('Tue'));
    await tester.pump();
    await tester.tap(find.text('Wed'));
    await tester.pump();
    expect(requests.keys, [0, 1, 2]);
    requests[1]!.completeError(StateError('stale Tuesday error'));
    await tester.pump();
    expect(find.text('Could not load the airing schedule.'), findsNothing);
    requests[2]!.complete([
      _entry(_media('Wednesday', anilistId: 2), at: DateTime(2026, 8, 19, 10)),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All anime'));
    await tester.pumpAndSettle();
    expect(find.text('Wednesday'), findsOneWidget);
    requests[0]!.complete([_entry(_media('Stale Monday', anilistId: 1))]);
    await tester.pumpAndSettle();
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Stale Monday'), findsNothing);
  });

  testWidgets(
    'failure has retry; an empty service response is not called nothing airing',
    (tester) async {
      final controller = _LibraryController();
      addTearDown(controller.dispose);
      var calls = 0;
      await tester.pumpWidget(
        _app(
          AnimeXScheduleList(
            controller: controller,
            weekday: 0,
            now: () => _now,
            loadSchedule: (_) async {
              calls++;
              if (calls == 1) throw StateError('offline');
              if (calls == 2) return [];
              return [_entry(_media('Recovered', anilistId: 1))];
            },
            onlyMyList: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load the airing schedule.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text('No schedule data for this day. It may be unavailable.'),
        findsOneWidget,
      );
      expect(find.textContaining('Nothing airing'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Recovered'), findsOneWidget);
      expect(calls, 3);
    },
  );

  testWidgets(
    'a loaded schedule with no personal matches explains the empty view',
    (tester) async {
      final controller = _LibraryController([_media('Saved', anilistId: 2)]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          AnimeXScheduleList(
            controller: controller,
            weekday: 0,
            now: () => _now,
            loadSchedule: (_) async => [_entry(_media('Other', anilistId: 1))],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No airings from your list in this day’s schedule.'),
        findsOneWidget,
      );
      expect(find.text('Other'), findsNothing);
    },
  );

  testWidgets('teaser limit is applied after matching, in local airing order', (
    tester,
  ) async {
    final first = _media('First saved', anilistId: 1);
    final last = _media('Last saved', anilistId: 2);
    final controller = _LibraryController([first, last]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        AnimeXScheduleList(
          controller: controller,
          weekday: 0,
          maxEntries: 1,
          now: () => _now,
          loadSchedule: (_) async => [
            _entry(last, at: DateTime(2026, 8, 17, 19)),
            _entry(
              _media('Not saved', anilistId: 3),
              at: DateTime(2026, 8, 17, 8),
            ),
            _entry(first),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First saved'), findsOneWidget);
    expect(find.text('Last saved'), findsNothing);
    expect(find.text('Not saved'), findsNothing);
  });

  testWidgets('finishing a request after disposal is safe', (tester) async {
    final controller = _LibraryController();
    addTearDown(controller.dispose);
    final pending = Completer<List<AnimexScheduleEntry>>();
    await tester.pumpWidget(
      _app(
        AnimeXScheduleList(
          controller: controller,
          weekday: 0,
          loadSchedule: (_) => pending.future,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('late error'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 800), const Size(768, 1024)]) {
    testWidgets('schedule fits $size with larger text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final saved = _media(
        'A long anime title that needs two lines on a phone',
        anilistId: 1,
      );
      final controller = _LibraryController([saved]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          AnimeXSchedulePage(
            controller: controller,
            now: () => _now,
            loadSchedule: (_) async => [_entry(saved)],
          ),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(saved.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
