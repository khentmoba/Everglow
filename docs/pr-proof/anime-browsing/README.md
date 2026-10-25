# Anime browsing UI proof

The before/after PNGs are Flutter widget renders of the production Anime home, header, poster rails and bottom navigation. Every title, synopsis and profile in those renders is synthetic; the artwork is the bundled `assets/images/demo/` artwork. No account data or private photos were loaded.

| Viewport | Before | After |
| --- | --- | --- |
| Phone, 430 × 932 | [Before](before-430.png) | [After](after-430.png) |
| Tablet, 820 × 1180 | [Before](before-820.png) | [After](after-820.png) |
| Desktop, 1440 × 1000 | [Before](before-1440.png) | [After](after-1440.png) |

The before renders use the six original Anime widgets from `99f323ad`, captured in this branch with the same synthetic catalog. At 820px the original header reports an 86px horizontal overflow, visible in the before image. The updated layout fits and exposes the first catalog shelf in the initial viewport.

The after renders show the shorter, content-sized spotlight, simpler metadata, quiet shelf headings, larger controls and readable bottom navigation. Large text is tested separately at 1.8× on 320px phones and 820px tablets.

Regenerate the after widget renders with the project's Flutter 3.47.7 SDK:

```sh
flutter test --no-pub --dart-define=PR_PROOF_DIR=docs/pr-proof/anime-browsing test/features/anime/anime_browsing_layout_test.dart
```

The `browser-430.jpg`, `browser-820.jpg` and `browser-1440.jpg` files show the release build in disposable headless Chrome 155 on Windows, in an isolated Agent Mode session with the HUD collapsed. These use the public anime catalog and its artwork. Search and My List were opened successfully; no uncaught JavaScript exceptions were observed. Playback and account synchronization were not tested.

The widget images establish layout with synthetic content. Neither the widget renders nor the Chrome run establishes iOS installed-app behavior. The final commands and results are recorded in the PR.
