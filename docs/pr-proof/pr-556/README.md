# PR #556 Proof: Web Context Menu & Text Copying Fix

## Problem
In PR #555, `SelectionArea` was added around root routes to enable app-wide text selection and copying. However, users reported they still could not select text and copy it on the live site.

## Root Cause
1. In Flutter Web with CanvasKit, Flutter enables the browser's context menu by default (`BrowserContextMenu.enabled = true`).
2. When the browser context menu is enabled, Flutter's `SelectableRegion` sets `_webContextMenuEnabled = true`.
3. Because `_webContextMenuEnabled` is true, Flutter explicitly suppresses its own context menu toolbar (`SelectableRegion._showToolbar()` returns `false`) and instead delegates context menu interactions to `PlatformSelectableRegionContextMenu`.
4. `PlatformSelectableRegionContextMenu` relies on an invisible DOM element that only intercepts right-clicks, and on right-click it calls `client.dispatchSelectionEvent(SelectWordSelectionEvent(...))`. This wiped out the user's dragged multi-word selection and collapsed it to a single word in the DOM.
5. In addition, `web/index.html` sets `-webkit-user-select: none; user-select: none;` on `html, body`. The browser's native context menu was shown over a `<canvas>` element without any copyable DOM text selection, preventing users from copying selected text via right-click.

## Solution
1. In `lib/main.dart` during app initialization on Web (`if (kIsWeb)`), call `await BrowserContextMenu.disableContextMenu()`.
2. When the browser's native context menu is disabled:
   - `BrowserContextMenu.enabled` becomes `false`.
   - `SelectableRegion._webContextMenuEnabled` becomes `false`.
   - Flutter's `AdaptiveTextSelectionToolbar` is displayed directly on right-click / secondary tap at the cursor location with "Copy" and "Select all" options.
   - Right-clicking preserves the active selection instead of clearing it.
   - Clicking "Copy" immediately invokes `Clipboard.setData` with the selected content.
   - On touch/mobile devices, long-pressing displays the selection handles and toolbar with "Copy".
3. Added unit and widget tests in `test/features/selection/text_selection_copy_test.dart` verifying desktop right-click copy behavior and mobile touch selection.

## Proof Artifacts
- `desktop-text-selection-context-menu.png`: Desktop anime screen showing selected text ("Action · Comedy · Fantasy") and the native Flutter context menu toolbar with "Copy" and "Select all" options.
- `phone-text-selection-context-menu.png`: Cinema screen in mobile viewport showing text selection and context menu.
- Unit and widget tests in `test/features/selection/text_selection_copy_test.dart` passing.
