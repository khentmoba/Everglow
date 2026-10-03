import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
// The Firebase plugins already depend on these interfaces; used only to fake auth.
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_billboard.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_hover_preview.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_touch_preview.dart';

class _Auth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform get currentUser => _User(this);
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth)
    : super(
        auth,
        _MultiFactor(auth),
        PigeonUserDetails(
          userInfo: PigeonUserInfo(
            uid: 'demo-only',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'fake-test-token';
}

MediaItem _item(int id) => MediaItem(
  id: 'demo-$id',
  tmdbId: id,
  title: 'Demo Title',
  mediaType: 'movie',
  posterPath: '',
  status: 'watching',
  addedAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _Auth();
  });

  for (final vote in [0.0, 3.2, 8.2, 10.0]) {
    for (final preview in ['billboard', 'hover', 'touch']) {
      testWidgets('$preview labels actual TMDB $vote/10 without a fake match', (
        tester,
      ) async {
        final id =
            92000 +
            (vote * 100).toInt() +
            ['billboard', 'hover', 'touch'].indexOf(preview);
        final item = _item(id);
        await http.runWithClient(
          () async {
            if (preview == 'billboard') {
              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: NetflixBillboard(
                      items: [item],
                      onPlay: (_) {},
                      onInfo: (_) {},
                    ),
                  ),
                ),
              );
            } else if (preview == 'hover') {
              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: NetflixHoverPreview(item: item, width: 324),
                    ),
                  ),
                ),
              );
            } else {
              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showTouchPreview(
                          context: context,
                          item: item,
                          inList: false,
                        ),
                        child: const Text('Options'),
                      ),
                    ),
                  ),
                ),
              );
              await tester.tap(find.text('Options'));
            }
            await tester.pumpAndSettle();
            expect(find.textContaining('% Match'), findsNothing);
            expect(
              find.text('TMDB ${vote.toStringAsFixed(1)}/10'),
              vote > 0 ? findsOneWidget : findsNothing,
            );
            expect(tester.takeException(), isNull);
            // Dispose billboard's timer before finishing the test.
            await tester.pumpWidget(const SizedBox.shrink());
          },
          () => MockClient((request) async {
            expect(
              request.url.host,
              'us-central1-everglow-1c6db.cloudfunctions.net',
            );
            expect(request.headers['Authorization'], 'Bearer fake-test-token');
            return http.Response(
              jsonEncode(
                request.url.path.endsWith('/videos')
                    ? {'results': []}
                    : {'vote_average': vote, 'overview': 'A fake synopsis.'},
              ),
              200,
            );
          }),
        );
      });
    }
  }
}
