# Build

```bash
cd web/table_tennis/src
npx tsc --noEmit      # typecheck
npx tsc               # emit to ../assets/js/dist
```

To try typed build in-browser:
- Open `web/table_tennis/assets/index.typed.html` directly, or
- Point the Flutter iframe src to `table_tennis/assets/index.typed.html?v=typed`:
  ```dart
  // lib/features/play_zone/table_tennis/presentation/screens/table_tennis_game_screen_web.dart:26
  static const String _gameSrc = 'table_tennis/assets/index.typed.html?v=1';
  ```

Rollback: revert `_gameSrc` to `table_tennis/assets/index.html?v=1`.
