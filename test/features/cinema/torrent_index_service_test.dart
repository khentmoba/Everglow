import 'dart:convert';

import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/services/torrent_index_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/torrent_download_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shaped like a real index payload: two info lines, emoji metadata,
/// optional trackers, and a few junk entries that must be dropped.
const _payload = {
  'streams': [
    {
      'name': 'Torrentio\n1080p',
      'title':
          'Moonlit Cinema 2025 1080p WEB-DL x264\n'
          '👤 840 💾 2.04 GB ⚙️ 1337x',
      'infoHash': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'behaviorHints': {
        'filename': 'Moonlit.Cinema.2025.1080p.WEB-DL.x264.mkv',
      },
    },
    {
      'name': 'Torrentio\n4k HDR',
      'title':
          'Moonlit Cinema 2025 2160p UHD BluRay\n'
          '👤 90 💾 15.80 GB ⚙️ YTS',
      'infoHash': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      'behaviorHints': {'filename': 'Moonlit.Cinema.2025.2160p.HDR.mkv'},
    },
    {
      // Same copy as the first row with worse seeding: deduped, max kept.
      'name': 'Torrentio\n1080p',
      'title':
          'Moonlit Cinema 2025 1080p WEB-DL x264\n👤 12 💾 2.04 GB ⚙️ 1337x',
      'infoHash': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      'behaviorHints': {
        'filename': 'Moonlit.Cinema.2025.1080p.WEB-DL.x264.mkv',
      },
    },
    {
      // Series row: no filename hint, trackers attached.
      'name': 'Torrentio\n720p',
      'title': 'Moonlit Cinema S01E03 720p HDTV\n👤 300 💾 780.5 MB ⚙️ EZTV',
      'infoHash': 'cccccccccccccccccccccccccccccccccccccccc',
      'sources': [
        'dht:cccccccccccccccccccccccccccccccccccccccc',
        'tracker:udp://tracker.openbittorrent.com:6969/announce',
      ],
    },
    {
      // Not a torrent (direct URL) and a malformed hash: both skipped.
      'name': 'Torrentio\n1080p',
      'title': 'direct link\n👤 5 💾 1 GB ⚙️ Web',
      'url': 'https://example.test/stream.mp4',
    },
    {'name': 'Torrentio\n1080p', 'infoHash': 'nope', 'title': '👤 1'},
  ],
};

class _FakeIndex extends TorrentIndexService {
  _FakeIndex(this.result);

  final TorrentSearch result;

  @override
  Future<TorrentSearch> search({
    required int tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TorrentIndexService.parseCopies', () {
    test('keeps real copies, drops junk, best seeded first', () {
      final copies = TorrentIndexService.parseCopies(jsonEncode(_payload));
      expect(copies.map((c) => c.infoHash), [
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'cccccccccccccccccccccccccccccccccccccccc',
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ]);
      final best = copies.first;
      expect(best.seeders, 840);
      expect(best.size, '2.04 GB');
      expect(best.provider, '1337x');
      expect(best.quality, '1080p');
      expect(best.filename, 'Moonlit.Cinema.2025.1080p.WEB-DL.x264.mkv');
      expect(copies[1].quality, '720p');
      expect(copies[1].filename, 'Moonlit Cinema S01E03 720p HDTV');
      expect(copies[2].quality, '4K');
    });

    test('magnet carries the hash, name and trackers', () {
      final copies = TorrentIndexService.parseCopies(jsonEncode(_payload));
      final series = copies[1];
      expect(series.magnet, startsWith('magnet:?xt=urn:btih:cccc'));
      expect(
        series.magnet,
        contains('tr=udp%3A%2F%2Ftracker.openbittorrent.com%3A6969%2Fannounce'),
      );
      // Movies come without trackers; public ones are added so the first
      // peer connect does not depend on DHT alone.
      expect(copies.first.magnet, contains('tracker.opentrackr.org'));
    });

    test('bad payloads are empty, never thrown', () {
      expect(TorrentIndexService.parseCopies('not json'), isEmpty);
      expect(TorrentIndexService.parseCopies('{"streams":[]}'), isEmpty);
      expect(TorrentIndexService.parseCopies('{}'), isEmpty);
    });
  });

  group('TorrentIndexService.search', () {
    tearDown(() {
      AgentMode.isActive.value = false;
      AgentMode.useDemoData.value = true;
    });

    test('agent mode returns demo copies, no network', () async {
      AgentMode.isActive.value = true;
      AgentMode.useDemoData.value = true;
      final result = await TorrentIndexService().search(
        tmdbId: 900001,
        mediaType: 'movie',
      );
      expect(result.copies, same(TorrentIndexService.demoCopies));
    });

    test(
      'an episode-less series asks for an episode instead of guessing',
      () async {
        AgentMode.isActive.value = false;
        final result = await TorrentIndexService().search(
          tmdbId: 900005,
          mediaType: 'tv',
        );
        expect(result.isEmpty, isTrue);
        expect(result.reason, 'Open an episode to download it.');
      },
    );
  });

  group('TorrentDownloadSheet', () {
    for (final width in [320.0, 430.0, 810.0]) {
      testWidgets('lists copies at ${width}px with large text', (tester) async {
        tester.view.physicalSize = Size(width, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.gamifiedTheme,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 932),
                  textScaler: const TextScaler.linear(1.5),
                ),
                child: TorrentDownloadSheet(
                  tmdbId: 900001,
                  mediaType: 'tv',
                  title: 'Moonlit Cinema',
                  season: 1,
                  episode: 3,
                  service: _FakeIndex(
                    const TorrentSearch(copies: TorrentIndexService.demoCopies),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Download · S1 E3'), findsOneWidget);
        expect(find.text('1080p'), findsOneWidget);
        expect(find.text('2.04 GB · 1284 seeds · Demo'), findsOneWidget);
        expect(
          find.text('Moonlit.Cinema.2025.1080p.WEB-DL.mp4'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('copy hands the magnet to the clipboard', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.gamifiedTheme,
          home: Scaffold(
            body: TorrentDownloadSheet(
              tmdbId: 900001,
              mediaType: 'movie',
              title: 'Moonlit Cinema',
              service: _FakeIndex(
                const TorrentSearch(copies: TorrentIndexService.demoCopies),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Copy link').first);
      await tester.pumpAndSettle();
      final copied = calls.where((c) => c.method == 'Clipboard.setData');
      expect(copied, isNotEmpty);
      expect(
        (copied.first.arguments as Map)['text'],
        TorrentIndexService.demoCopies.first.magnet,
      );
      expect(find.byTooltip('Copied'), findsOneWidget);
    });

    testWidgets('no copies shows the honest reason and a retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.gamifiedTheme,
          home: Scaffold(
            body: TorrentDownloadSheet(
              tmdbId: 900001,
              mediaType: 'movie',
              title: 'Moonlit Cinema',
              service: _FakeIndex(
                const TorrentSearch(reason: 'No copies found for this title.'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No copies found for this title.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
