import 'package:everglow/core/models/presence_status.dart';
import 'package:everglow/core/services/auth_service.dart';
import 'package:everglow/core/services/presence_service.dart';
import 'package:everglow/shared/widgets/partner_doodle_indicator.dart';
import 'package:everglow/shared/widgets/partner_presence_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Auth extends ChangeNotifier implements AuthService {
  int reads = 0;
  @override
  String get partnerUid => 'demo-partner';
  @override
  String get partnerName {
    reads++;
    return 'Demo partner';
  }

  @override
  bool get isCoupleUser => true;
  @override
  bool get isResolvingPartner => false;
  @override
  Future<void> refreshPartnerLink() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Presence implements PresenceService {
  int watches = 0;
  @override
  Stream<PresenceStatus> watchPresence(String uid) {
    watches++;
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('partner freshness timers stop hidden and refresh on return', (
    tester,
  ) async {
    final auth = _Auth();
    final presence = _Presence();
    final enabled = ValueNotifier(true);
    addTearDown(auth.dispose);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          Provider<PresenceService>.value(value: presence),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (_, active, child) =>
                TickerMode(enabled: active, child: child!),
            child: const Column(
              children: [PartnerDoodleIndicator(), PartnerPresenceIndicator()],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final start = auth.reads;
    await tester.pump(const Duration(seconds: 2));
    expect(auth.reads, greaterThan(start));
    expect(presence.watches, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    final hidden = auth.reads;
    await tester.pump(const Duration(seconds: 60));
    expect(auth.reads, hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(auth.reads, greaterThan(hidden));
    enabled.value = false;
    await tester.pump();
    final offstage = auth.reads;
    await tester.pump(const Duration(seconds: 60));
    expect(auth.reads, offstage);
    enabled.value = true;
    await tester.pump();
    expect(auth.reads, greaterThan(offstage));
    expect(presence.watches, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
