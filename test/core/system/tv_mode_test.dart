import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/core/system/tv_mode.dart';
import 'package:everglow/shared/widgets/everglow/everglow_button.dart';
import 'package:everglow/shared/widgets/shelf/shelf_icon_button.dart';
import 'package:everglow/shared/widgets/shelf/tv_media_nav_header.dart';

class _MockAuthService extends ChangeNotifier implements AuthService {
  bool _isCinemaOnly = false;
  bool _isCouple = false;

  void setFlags({bool isCinemaOnly = false, bool isCouple = false}) {
    _isCinemaOnly = isCinemaOnly;
    _isCouple = isCouple;
    notifyListeners();
  }

  @override
  bool get isCinemaOnlyUser => _isCinemaOnly;

  @override
  bool get isCoupleUser => _isCouple;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TvMode.isTvMode.value = false;
  });

  group('TvMode key helpers', () {
    test('isSelectKey identifies TV remote selection keys', () {
      expect(TvMode.isSelectKey(LogicalKeyboardKey.enter), isTrue);
      expect(TvMode.isSelectKey(LogicalKeyboardKey.numpadEnter), isTrue);
      expect(TvMode.isSelectKey(LogicalKeyboardKey.select), isTrue);
      expect(TvMode.isSelectKey(LogicalKeyboardKey.space), isTrue);
      expect(TvMode.isSelectKey(LogicalKeyboardKey.gameButtonA), isTrue);
      expect(TvMode.isSelectKey(LogicalKeyboardKey.arrowDown), isFalse);
      expect(TvMode.isSelectKey(LogicalKeyboardKey.keyA), isFalse);
    });

    test('isBackKey identifies TV remote back keys', () {
      expect(TvMode.isBackKey(LogicalKeyboardKey.escape), isTrue);
      expect(TvMode.isBackKey(LogicalKeyboardKey.backspace), isTrue);
      expect(TvMode.isBackKey(LogicalKeyboardKey.goBack), isTrue);
      expect(TvMode.isBackKey(LogicalKeyboardKey.browserBack), isTrue);
      expect(TvMode.isBackKey(LogicalKeyboardKey.gameButtonB), isTrue);
      expect(TvMode.isBackKey(LogicalKeyboardKey.arrowLeft), isFalse);
    });

    test('isTvUserAgent detects Android TV and Smart TV browsers', () {
      expect(
        TvMode.isTvUserAgent(
          'Mozilla/5.0 (Linux; Android 11; SHIELD Android TV) AppleWebKit/537.36',
        ),
        isTrue,
      );
      expect(
        TvMode.isTvUserAgent(
          'Mozilla/5.0 (Linux; Android 12; MiBOX4) AppleWebKit/537.36',
          maxTouchPoints: 0,
          isLandscape: true,
        ),
        isTrue,
      );
      expect(
        TvMode.isTvUserAgent(
          'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
          maxTouchPoints: 0,
          isLandscape: true,
        ),
        isTrue,
      );
      // Mobile phone with touch should NOT trigger TV mode
      expect(
        TvMode.isTvUserAgent(
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Mobile Safari/537.36',
          maxTouchPoints: 5,
          isLandscape: true,
        ),
        isFalse,
      );
      // Android tablet with touch should NOT trigger TV mode
      expect(
        TvMode.isTvUserAgent(
          'Mozilla/5.0 (Linux; Android 14; Tab S9) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
          maxTouchPoints: 5,
          isLandscape: true,
        ),
        isFalse,
      );
      // Desktop browser should NOT trigger TV mode
      expect(
        TvMode.isTvUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
          maxTouchPoints: 0,
          isLandscape: true,
        ),
        isFalse,
      );
    });

    test('digitFromKey extracts digits from regular and numpad keys', () {
      expect(TvMode.digitFromKey(LogicalKeyboardKey.digit0), '0');
      expect(TvMode.digitFromKey(LogicalKeyboardKey.digit5), '5');
      expect(TvMode.digitFromKey(LogicalKeyboardKey.numpad9), '9');
      expect(TvMode.digitFromKey(LogicalKeyboardKey.numpad1), '1');
      expect(TvMode.digitFromKey(LogicalKeyboardKey.keyA), isNull);
      expect(TvMode.digitFromKey(LogicalKeyboardKey.enter), isNull);
    });

    test('toggle and setTvMode update isTvMode value', () async {
      expect(TvMode.isTvMode.value, isFalse);
      await TvMode.setTvMode(true);
      expect(TvMode.isTvMode.value, isTrue);
      await TvMode.toggle();
      expect(TvMode.isTvMode.value, isFalse);
    });

    test('focus styling helpers return valid border and shadows', () {
      final border = TvMode.focusBorder();
      expect(border.top.width, 3.0);

      final shadows = TvMode.focusShadows();
      expect(shadows.length, 2);
      expect(shadows.first.blurRadius, 18.0);
    });
  });

  group('TvMediaNavHeader widget', () {
    testWidgets('renders nothing when TvMode is inactive', (tester) async {
      TvMode.isTvMode.value = false;
      final mockAuth = _MockAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthService>.value(
            value: mockAuth,
            child: const Scaffold(
              body: TvMediaNavHeader(currentRoute: '/cinema'),
            ),
          ),
        ),
      );

      expect(find.byType(TvMediaNavHeader), findsOneWidget);
      expect(find.text('Cinema'), findsNothing);
      expect(find.text('Anime'), findsNothing);
      expect(find.text('MangaCelestia'), findsNothing);
    });

    testWidgets('renders TV navigation tabs when TvMode is active',
        (tester) async {
      TvMode.isTvMode.value = true;
      final mockAuth = _MockAuthService()..setFlags(isCinemaOnly: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthService>.value(
            value: mockAuth,
            child: const Scaffold(
              body: TvMediaNavHeader(currentRoute: '/cinema'),
            ),
          ),
        ),
      );

      expect(find.text('Cinema'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('MangaCelestia'), findsOneWidget);
      expect(find.text('TV'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);
      // Guests cannot access dashboard
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets('renders Dashboard tab for couple users in TvMode',
        (tester) async {
      TvMode.isTvMode.value = true;
      final mockAuth = _MockAuthService()..setFlags(isCouple: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthService>.value(
            value: mockAuth,
            child: const Scaffold(
              body: TvMediaNavHeader(currentRoute: '/cinema'),
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Cinema'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('MangaCelestia'), findsOneWidget);
    });
  });

  group('Android TV remote Select key activation', () {
    testWidgets('EverglowButton activates on LogicalKeyboardKey.select',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EverglowButton(
                label: 'Play',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Focus the button via Tab, then press Android TV Select
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('ShelfIconButton activates on LogicalKeyboardKey.select',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ShelfIconButton(
                icon: Icons.search_rounded,
                semanticLabel: 'Search',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('TV arrow shortcuts move focus across horizontal buttons',
        (tester) async {
      var firstPressed = false;
      var secondPressed = false;
      final firstNode = FocusNode(debugLabel: 'first');
      final secondNode = FocusNode(debugLabel: 'second');
      addTearDown(() {
        firstNode.dispose();
        secondNode.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          shortcuts: {
            ...WidgetsApp.defaultShortcuts,
            const SingleActivator(LogicalKeyboardKey.arrowRight):
                const DirectionalFocusIntent(TraversalDirection.right),
            const SingleActivator(LogicalKeyboardKey.select):
                const ActivateIntent(),
          },
          home: Scaffold(
            body: Row(
              children: [
                TextButton(
                  focusNode: firstNode,
                  autofocus: true,
                  onPressed: () => firstPressed = true,
                  child: const Text('First'),
                ),
                TextButton(
                  focusNode: secondNode,
                  onPressed: () => secondPressed = true,
                  child: const Text('Second'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(firstNode.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(secondNode.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(firstPressed, isFalse);
      expect(secondPressed, isTrue);
    });
  });
}
