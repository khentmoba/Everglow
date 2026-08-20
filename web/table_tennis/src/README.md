# Table Tennis World Tour — Typed Refactor

Typed ES2020 port of `web/table_tennis/assets/js/game.js` (Famobi 1.0.2, 5300 lines).
No runtime behavior change — purely adds types, modules, and explicit deps.

## Layout
```
src/
  types/index.ts         # GameState, HitData, OImageIds, BallStateDTO, etc.
  utils/constants.ts     # PHYSICS/TABLE/SCORING, ENEMY_CUPS, MAP_MARKER_POS
  utils/famobi.ts        # Famobi/LeChuck typed stubs
  utils/audio.ts         # Howler wrapper
  core/asset_loader.ts   # Utils.AssetLoader
  core/anim_sprite.ts    # AnimSprite, BasicSprite
  core/user_input.ts     # UserInput (touch/mouse/pointer-lock)
  core/save_data.ts      # SaveDataHandler (localStorage tabletennisv3)
  core/country_flags.ts  # CountryFlags
  core/fps_meter.ts      # FpsMeter
  elements/table_top.ts
  elements/user_bat.ts
  elements/enemy_bat.ts
  elements/ball.ts       # 250L physics — the core to tweak
  elements/background.ts
  elements/panel.ts
  game/game.ts           # Game orchestrator (state machine + loops)
  mp_bridge.ts           # TTMultiplayer typed bridge
  index.ts               # entry — window.extGameLoad / window.TTGame
```

## Build
```bash
cd web/table_tennis/src
npx tsc --noEmit          # typecheck
npx tsc                   # emit to ../assets/js/dist/
# then point assets/index.html at dist/index.js instead of js/game.js
```

`tsconfig.json` → `target ES2020, module ESNext, strict, outDir ../assets/js/dist`.

## Key physics constants (utils/constants.ts)
- `PHYSICS.gravity = 3800`
- `spinPowUser 2.5 / spinPowEnemy 2.0`
- `winScore 11, winBy 2`
- `TABLE.heightFactor 235, widthFactor 233`

## Patch guide
| Want | Edit |
|------|------|
| Make AI harder | `elements/enemy_bat.ts:skillLevel` formula + `badAim` threshold |
| Faster ball | `ball.ts:setBouncePoint` speed calc, `PHYSICS.gravity` |
| First to 7 | `utils/constants.ts:SCORING.winScore` |
| Unlock all cups | `core/save_data.ts:clearData` → `aLevelStore=[7,7,…]` |
| Custom paddle | `elements/user_bat.ts:getHitData` |

## MP
`mp_bridge.ts` keeps `window.TTMultiplayer` shape so Flutter `tt_bridge_service.dart:29` still works.
New code can `import {installMPHooks} from './mp_bridge.js'`.

## Notes
- `oImageIds` populated at runtime in `game/game.ts:loadAssets()` mirroring `game.js:5133`.
- Glob `web/table_tennis/assets/index.html` still shims `AssetLoader.loadImage` for 64×64 placeholders — keep it.
- Original `js/game.js` / `app37.js` left untouched; flip `<script src="js/game.js">` to `js/dist/index.js` to use typed build.
