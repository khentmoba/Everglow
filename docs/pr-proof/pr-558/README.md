# PR #558 proof: copy text inside popups

Local release build, Agent Mode, demo data only.

- `before-desktop-popup.png`: Cinema → More Info on current `main`. Dragged
  across "Moonlit Cinema" and right-clicked: nothing highlights, no menu.
- `after-desktop-popup.png`: same steps on this branch. The title highlights
  and Copy / Select all appears. Copy and Ctrl+C both put "Moonlit Cinema" on
  the clipboard, and pressing Escape still closes the popup.
- `after-phone-popup.png`: 390px iPhone (Safari user agent, `navigator.platform`
  set to iPhone). Long-press on "friendship" shows handles and the iOS
  Copy / Select All bar; Copy put "friendship" on the clipboard.
