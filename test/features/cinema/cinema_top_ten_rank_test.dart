import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _DemoAuth extends ChangeNotifier implements AuthService {
  @override
  bool get isCoupleUser => true;
  @override
  String get currentUser => 'khentsgdz';
  @override
  String get partnerUsername => 'clairjassen';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaItem _item(int tmdbId, {String mediaType = 'movie'}) => MediaItem(
  id: 'demo-$tmdbId',
  tmdbId: tmdbId,
  title: 'Demo $tmdbId',
  mediaType: mediaType,
  posterPath: '',
  status: '',
  addedAt: DateTime(2026),
);

Future<void> _pumpDrawer(WidgetTester tester, _DemoAuth auth, int? rank) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: MaterialApp(
        home: Scaffold(
          body: EpisodeDrawer(
            key: ValueKey(rank),
            item: _item(1),
            cinemaVariant: true,
            topTenRank: rank,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  // Guards the lookup that turns a tapped item into its Top 10 badge rank:
  // the bug this test suite exists for showed "#2" for every item.
  group('topTenRankFor', () {
    final topTen = [_item(1), _item(2), _item(3)];

    test('first item is rank 1', () {
      expect(topTenRankFor(topTen, _item(1)), 1);
    });

    test('tenth item is rank 10', () {
      final ten = List.generate(10, (i) => _item(i + 1));
      expect(topTenRankFor(ten, _item(10)), 10);
    });

    test('items past tenth show no rank', () {
      final many = List.generate(12, (i) => _item(i + 1));
      expect(topTenRankFor(many, _item(11)), isNull);
    });

    test('items outside the list show no rank', () {
      expect(topTenRankFor(topTen, _item(99)), isNull);
    });

    test('same tmdbId with different mediaType is a different item', () {
      final mixed = [_item(5, mediaType: 'movie')];
      expect(topTenRankFor(mixed, _item(5, mediaType: 'tv')), isNull);
    });
  });

  testWidgets('drawer badge shows the rank it was given', (tester) async {
    AgentMode.isActive.value = true;
    final auth = _DemoAuth();
    addTearDown(() {
      AgentMode.isActive.value = false;
      auth.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    for (final font in ['Outfit', 'CormorantGaramond']) {
      final loader = FontLoader(font == 'Outfit' ? font : 'Cormorant Garamond');
      loader.addFont(rootBundle.load('assets/google_fonts/$font-SemiBold.ttf'));
      await tester.runAsync(loader.load);
    }

    for (final rank in [1, 2, 10, null]) {
      await _pumpDrawer(tester, auth, rank);
      expect(
        find.textContaining('in the Philippines Today'),
        rank == null ? findsNothing : findsOneWidget,
      );
      if (rank != null) {
        expect(find.text('#$rank in the Philippines Today'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
