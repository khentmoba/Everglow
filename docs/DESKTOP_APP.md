# Desktop download and updates

The website's `DesktopAppAction` appears before login on the entrance and
under the Dashboard heading. Windows browsers download the stable installer;
other platforms open the desktop release information instead of an executable.
Desktop builds with the bridge show their native version and request a native
update check. Older desktop builds can use **Everglow > Check for Updates**.

Desktop source: `khentmoba/Everglow-Desktop` (Tauri, separate from this Flutter
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

- Widget tests cover Windows download selection, phone information links and
  retryable launch errors.
- `flutter test --platform chrome test/desktop_app_browser_test.dart`
  covers the bridge and the native-version update button with a fake callback.
  Quality includes this test in its browser suite. Flutter 3.44.4's local
  Windows test server can fail to serve `/canvaskit/` (HTTP 404); report that
  runner failure separately from app failures and use the Linux CI result.
- Desktop Rust tests reject lookalike origins and unknown actions. Its fake-page
  WebView2 suite checks bridge injection without accessing couple data or
  checking the live update feed.
- Before publishing, test an actual installed 0.2.0-to-0.3.0 signed upgrade.
  Fake bridge tests do not prove installer execution or session preservation.
