# Startup, Slow-Network, and Phone Optimization Proof

## Overview

This pass targets cold and warm startup pipeline latency, low-spec device frame overhead, and slow network connection resilience across Everglow.

## Changes

1. **Startup Pipeline Concurrency (`lib/core/system/app_bootstrap.dart`, `lib/main.dart`)**:
   - `AppBootstrap.run()` now executes environment configuration concurrently with `Firebase.initializeApp()` rather than sequentially awaiting a potential 404 HTTP fetch on web.
   - `_startEverglow()` runs `bootstrap.run()` concurrently with preference/route/scroll memory restoration (`PerfSettings.load()`, `AgentMode.init()`, `RouteMemory.load()`, `ScrollMemory.preload()`).
   - `BrowserContextMenu.disableContextMenu()` is invoked non-blocking on web instead of blocking the first frame event loop.
   - Decoded-image cache maximum bounds are set immediately upon initialization.

2. **Phone & Low-End Image Loading (`lib/shared/widgets/app_network_image.dart`)**:
   - `AppNetworkImage` loading placeholder honors `AppMotion.reduceAmbientMotion(context)` on phones and constrained devices by suppressing continuous 60fps `CircularProgressIndicator` ticker loops during multi-image network loading.

3. **Doorway Responsiveness (`lib/features/entry/presentation/widgets/animated_door.dart`)**:
   - Low-end hardware (`DeviceCapability.isLowEndDevice`) accelerates door entrance animation to 500ms (from 1400ms) so keypad input is immediately responsive.

4. **Dashboard Hero Entrance (`lib/features/dashboard/presentation/screens/dashboard_screen.dart`)**:
   - Hero sliver uses a 150ms gentle opacity fade instead of heavy 700ms `FadeInDown` translation on low-end devices.

5. **Auth DNS Prefetch (`web/index.html`)**:
   - Added `dns-prefetch` for `identitytoolkit.googleapis.com` and `securetoken.googleapis.com` during HTML parsing.

## Verification

- **Analyzer**: `flutter analyze` passes with 0 issues.
- **Unit & Widget Tests**: 1,823 tests pass (`flutter test --exclude-tags="golden,network"`), including new concurrency regression test in `test/core/system/app_bootstrap_test.dart`.
- **Harness Suite**: 24/24 Node tests pass (`node --test tool/perf/harness.test.mjs`).
- **Service Worker Tests**: 15/15 tests pass (`node --test tool/service_worker_test.mjs`).
- **CI Guards**: All 15 repo guards pass.
- **Agent Smoke**: All 64 route checks pass across 430px and 810px viewports (`node tool/agent_smoke.mjs`).
- **Cold Boot Benchmark**: First Flutter Frame median 1405ms (unthrottled cold), DCL ~17-20ms, splash paint ~15-18ms.
- **Repeat Warm Open Benchmark**: First Flutter Frame 672.5ms (sub-second warm open), worst long task 167ms (within 200ms budget), FCP 32ms, LCP 32ms.
