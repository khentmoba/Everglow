import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/perf/device_capability.dart';
import 'package:everglow/core/theme/app_motion.dart';

void main() {
  setUp(() {
    DeviceCapability.debugReset();
  });

  tearDown(() {
    DeviceCapability.debugReset();
  });

  group('DeviceCapability', () {
    test('defaults to non-low-end on capable hardware', () {
      DeviceCapability.debugOverrideCores = 8;
      DeviceCapability.debugOverrideMemory = 8.0;

      expect(DeviceCapability.hardwareConcurrency, 8);
      expect(DeviceCapability.deviceMemory, 8.0);
      expect(DeviceCapability.isLowEndDevice, isFalse);
    });

    test('flags low-end when CPU cores <= 4', () {
      DeviceCapability.debugOverrideCores = 4;
      DeviceCapability.debugOverrideMemory = 8.0;

      expect(DeviceCapability.isLowEndDevice, isTrue);

      DeviceCapability.debugOverrideCores = 2;
      expect(DeviceCapability.isLowEndDevice, isTrue);
    });

    test('flags low-end when RAM <= 4 GB', () {
      DeviceCapability.debugOverrideCores = 8;
      DeviceCapability.debugOverrideMemory = 4.0;

      expect(DeviceCapability.isLowEndDevice, isTrue);

      DeviceCapability.debugOverrideMemory = 2.0;
      expect(DeviceCapability.isLowEndDevice, isTrue);
    });

    test('debugOverrideLowEnd takes precedence', () {
      DeviceCapability.debugOverrideCores = 8;
      DeviceCapability.debugOverrideMemory = 16.0;
      DeviceCapability.debugOverrideLowEnd = true;

      expect(DeviceCapability.isLowEndDevice, isTrue);

      DeviceCapability.debugOverrideCores = 2;
      DeviceCapability.debugOverrideMemory = 1.0;
      DeviceCapability.debugOverrideLowEnd = false;

      expect(DeviceCapability.isLowEndDevice, isFalse);
    });
  });

  group('AppMotion.reduceAmbientMotion with DeviceCapability', () {
    testWidgets('activates on desktop/tablet when device is low-end', (
      tester,
    ) async {
      DeviceCapability.debugOverrideLowEnd = true;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)), // desktop/tablet
            child: Builder(
              builder: (context) {
                final reduced = AppMotion.reduceAmbientMotion(context);
                return Text('reduced: $reduced');
              },
            ),
          ),
        ),
      );

      expect(find.text('reduced: true'), findsOneWidget);
    });

    testWidgets('keeps motion on capable desktop/tablet', (tester) async {
      DeviceCapability.debugOverrideLowEnd = false;
      DeviceCapability.debugOverrideCores = 8;
      DeviceCapability.debugOverrideMemory = 16.0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Builder(
              builder: (context) {
                final reduced = AppMotion.reduceAmbientMotion(context);
                return Text('reduced: $reduced');
              },
            ),
          ),
        ),
      );

      expect(find.text('reduced: false'), findsOneWidget);
    });
  });
}
