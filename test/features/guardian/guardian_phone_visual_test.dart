import 'package:everglow/features/guardian/presentation/controllers/guardian_controller.dart';
import 'package:everglow/features/guardian/presentation/widgets/character/cat_visuals.dart';
import 'package:everglow/features/guardian/presentation/widgets/everglow_guardian.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Guardian extends ChangeNotifier implements GuardianController {
  int taps = 0;
  bool aiMode = false;

  @override
  bool get isAIMode => aiMode;
  @override
  bool get isMessageVisible => false;
  @override
  bool get isMoodPromptVisible => false;
  @override
  Null get currentMessage => null;
  @override
  void welcome() {}
  @override
  void react() => taps++;
  @override
  void toggleAIMode() {
    aiMode = !aiMode;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/google_fonts/Outfit-Medium.ttf'));
    await font.load();
  });
  testWidgets('phone cat stays tappable without mounting a 3D viewer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(414, 896);
    addTearDown(tester.view.reset);
    final guardian = _Guardian();
    addTearDown(guardian.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<GuardianController>.value(
        value: guardian,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: EverglowGuardian())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = find.byType(Image);
    expect(image, findsOneWidget);
    expect(
      (tester.widget<Image>(image).image as AssetImage).assetName,
      'assets/images/guardian_cat.png',
    );
    expect(find.byType(CatVisuals), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.tap(image);
    await tester.pump(const Duration(seconds: 1));
    expect(guardian.taps, 1);
    await tester.longPress(image);
    await tester.pump(const Duration(seconds: 1));
    expect(guardian.isAIMode, isTrue);
    await tester.tap(image);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    // A fresh guardian must restore its 3D view on a tablet, including resize.
    await tester.pumpWidget(
      ChangeNotifierProvider<GuardianController>.value(
        value: guardian,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: EverglowGuardian())),
        ),
      ),
    );
    tester.view.physicalSize = const Size(810, 1080);
    await tester.pump();
    expect(find.byType(CatVisuals), findsOneWidget);
    tester.view.physicalSize = const Size(896, 414);
    await tester.pumpAndSettle();
    expect(find.byType(CatVisuals), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
