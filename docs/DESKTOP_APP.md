# Desktop download and updates

The Dashboard's **Desktop App** quick action opens `/desktop-app`
(`react/src/features/dashboard/DesktopAppPage.tsx`, signed-in only). Windows
browsers download the stable installer; other platforms open the desktop
release page instead of an executable. Inside the desktop app, the page reads
the native bridge to show the native version and request an update check.
Older desktop builds can use **Everglow > Check for Updates**.

Desktop source: `khentmoba/Everglow-Desktop` (Tauri, separate from this
repository). Its native version and the website version are independent.

## Release order

1. Merge and release desktop 0.3.0, which adds the fixed-action bridge and
   publishes `Everglow-Desktop-Setup.exe` alongside the signed updater artifacts.
2. Verify the stable download and `latest.json` without GitHub authentication.
3. Merge the website controls. Do not deploy a link to an unpublished asset.

Stable download:
https://github.com/khentmoba/Everglow-Desktop/releases/latest/download/Everglow-Desktop-Setup.exe

Version 0.2.0 can update through its existing menu/startup prompt. Version 0.1.0
requires one manual installer upgrade. Downloads use the public desktop release;
app sign-in and cinema/couple permissions remain unchanged.

## Native bridge

Only the top-level production Everglow document receives
`__everglowDesktopVersion` and `__everglowCheckForUpdates()`. The native handler
accepts one fixed message from the exact HTTPS origin. It accepts no download
URL or general native commands. No Tauri capabilities are granted to the site.

The native updater asks to download, verifies the package signature, then asks
to restart. Later retains that verified package for the current session. It
does not force a restart during playback. Closing the app discards the staged
download; the next launch checks again. Existing ad blocking stays enabled.

## Verification

- `react/tools/regressions.test.mjs` opens `/desktop-app?agent=1` and checks
  its back button returns to the Dashboard.
- The page reads the bridge as `window.everglowDesktop.{version,
  checkForUpdates}`; the native side injects `__everglowDesktopVersion` and
  `__everglowCheckForUpdates` (`src-tauri/src/website_bridge.rs`). Match the
  two names before relying on the in-app update button.
- Desktop Rust tests reject lookalike origins and unknown actions. Its fake-page
  WebView2 suite checks bridge injection without accessing couple data or
  checking the live update feed.
- Before publishing, test an actual installed signed upgrade. Fake bridge
  tests do not prove installer execution or session preservation.
