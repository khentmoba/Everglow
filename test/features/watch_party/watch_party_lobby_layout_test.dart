import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/watch_party/data/models/watch_party_room.dart';
import 'package:everglow/features/watch_party/presentation/widgets/watch_party_lobby.dart';

WatchPartyRoom _room({required bool active, String posterPath = ''}) {
  return WatchPartyRoom(
    id: 'demo',
    name: 'Movie Night',
    hostUid: 'a',
    hostName: 'Khent',
    partnerUid: 'b',
    partnerName: 'Clair',
    mediaType: 'tv',
    tmdbId: 1399,
    isAnime: false,
    season: 2,
    episode: 5,
    title: 'A Very Long Demo Series Title That Should Ellipsize',
    posterPath: posterPath,
    state: 'paused',
    currentTime: 0,
    updatedAt: DateTime.now(),
    updatedBy: 'a',
    createdAt: DateTime.now(),
    active: active,
  );
}

Widget _wrap(Widget child, Size size) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(width: size.width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  for (final size in const [
    Size(320, 640), // small phone
    Size(430, 932), // Clair's phone
    Size(800, 1280), // tablet
  ]) {
    testWidgets('room card has no overflow on ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          WatchPartyRoomCard(
            room: _room(active: true),
            myUid: 'a',
            onTap: () {},
          ),
          size,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Movie Night'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
    });
  }

  testWidgets('idle room card keeps its labels on a phone', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        WatchPartyRoomCard(
          room: _room(active: false),
          myUid: 'a',
          onTap: () {},
        ),
        const Size(430, 932),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('IDLE'), findsOneWidget);
    expect(find.text('You are hosting'), findsOneWidget);
  });

  testWidgets('long press asks to delete the room', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var longPressed = false;
    await tester.pumpWidget(
      _wrap(
        WatchPartyRoomCard(
          room: _room(active: false),
          myUid: 'a',
          onTap: () {},
          onLongPress: () => longPressed = true,
        ),
        const Size(430, 932),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(WatchPartyRoomCard));
    expect(longPressed, isTrue);
  });
}
