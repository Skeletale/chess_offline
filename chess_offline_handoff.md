# Chess Offline — Project Handoff Document

## Project Overview

An offline chess Android app built with Flutter/Dart for personal use.
- Play solo, vs AI bot, or vs a friend on the same device (pass-and-play)
- Fully offline, personal APK install (no Play Store)

---

## Tech Stack

- **Framework:** Flutter (Dart)
- **State management:** Provider (added to pubspec.yaml, not actively used — game state is managed via plain StatefulWidget/setState so far)
- **Sound:** audioplayers (fully implemented — see Phase 6)
- **Persistence:** shared_preferences (used for saved board theme)
- **Editor:** VS Code
- **Test device:** Redmi Note 10 Pro, Android 13, USB debugging
- **Dev machine:** Windows 11, Zyrex Ultra N100, 8GB RAM

---

## Agreed Features (from spec sessions)

### Must-have (ALL COMPLETE)
- Legal move enforcement (castling, en passant, promotion) ✅
- Check / checkmate / stalemate detection ✅
- Basic board UI with unicode pieces ✅
- Tap-to-move with legal move highlights ✅
- Local two-player pass-and-play ✅
- Undo / move history ✅
- Draw rules: threefold repetition, 50-move rule, insufficient material ✅
- Time controls: 5 min / 10 min / Unlimited ✅
- AI opponent with minimax + alpha-beta pruning (multiple difficulty levels) ✅
- Captured pieces display ✅ (added during Phase 5, not originally scoped but small enough to fold in)
- Board themes ✅ (Phase 6)
- Sound effects ✅ (Phase 6)

### Nice-to-have (deferred)
- Online multiplayer ❌ Phase 7 — originally scoped as "maybe later," not a hard requirement. All must-have features are now complete without it.
- Custom piece image sets (currently Unicode symbols, which look clean) — not planned unless requested

### Time control rules (agreed in spec, all implemented)
- Per-player countdown clocks ✅
- Clock pauses when app is backgrounded ✅
- Undo restores time spent on undone move ✅
- Timeout = loss (unless opponent has insufficient material → draw) ✅

### AI rules (agreed in spec, all implemented)
- Minimax (negamax formulation) + alpha-beta pruning (NOT Stockfish) ✅
- 3 difficulty levels controlled by search depth + randomness: Easy (depth 2, 30% random move), Medium (depth 3), Hard (depth 4) ✅
- Player can choose to play as White or Black (AI takes the other side) ✅
- Runs on a separate Isolate via `compute()` so UI doesn't freeze during think time ✅
- Minimum 2-second "thinking" delay enforced on every AI move so responses don't feel instant/unnatural ✅

### Theme rules (agreed in spec, all implemented)
- 4 presets: Classic Green, Brown Wood, Blue Ocean, Gray Coral ✅
- Picker accessed via a palette icon button on the Setup screen (not a separate settings screen) ✅
- Selected theme persists across app restarts via shared_preferences ✅

### Sound rules (agreed in spec, all implemented)
- 4 sound effects: move, capture, check, game-end ✅
- Sourced as CC0/free-license files from Freesound.org and Kenney.nl (see "Sound Assets" section below) ✅
- Low-latency, no-delay playback even on rapid move sequences ✅

---

## Project Structure

```
chess_offline/
  assets/
    sounds/
      move.wav                ✅ CC0 (Freesound - mh2o)
      capture.mp3              ✅ CC0 (Freesound - el_boss)
      check.ogg                 ✅ CC0 (Kenney UI Audio pack)
      game_end.ogg                ✅ CC0 (Kenney UI Audio pack)
    icon/
      app_icon.png             ✅ custom-designed pawn silhouette icon (1024x1024)
  lib/
    main.dart                     ✅ complete — preloads sounds at startup, launches SetupScreen
    core/
      move_generator.dart         ✅ complete
      game_state.dart              ✅ complete
      clock.dart                    ✅ complete
      time_control.dart              ✅ complete
      ai_engine.dart                   ✅ complete
      theme_storage.dart                ✅ complete
      sound_manager.dart                 ✅ complete
    models/
      piece.dart                          ✅ complete
      position.dart                         ✅ complete
      move.dart                              ✅ complete
      board.dart                               ✅ complete
      board_theme.dart                          ✅ complete
    state/                                      (empty — provider added but not wired up; state currently lives in StatefulWidgets)
    ui/
      screens/
        setup_screen.dart                        ✅ complete (game mode, difficulty, play-as-color, time control, theme picker)
        game_screen.dart                          ✅ complete (board, clocks, undo, captured pieces, sound triggers)
      widgets/
        chess_board.dart                           ✅ complete (theme-aware rendering)
```

---

## Completed Phases

### Phase 0 — Project Scaffolding ✅
- Flutter project created: `chess_offline`
- Folder structure set up
- Dependencies added: `provider`, `audioplayers`, `shared_preferences`
- App confirmed running on Redmi Note 10 Pro via USB debugging

### Phase 1 — Core Chess Engine ✅
All headless (no UI dependency), pure Dart logic.

**Models (`lib/models/`):**
- `piece.dart` — `PieceType` enum, `PieceColor` enum, `Piece` class
- `position.dart` — `Position(row, col)`, algebraic notation helpers, `offset()`, `isValid`
- `move.dart` — `Move` class with from/to/piece/capturedPiece/special/promotionType, `SpecialMove` enum
- `board.dart` — 8x8 grid, castling rights, en passant target, halfmove clock, move history, `Board.initial()`, `clone()`, `findKing()`, `toAscii()`

**Core logic (`lib/core/`):**
- `move_generator.dart` — Pseudo-legal move generation for all piece types + `isSquareAttacked()`. Includes castling (with attack detection on king path), en passant, and pawn promotion (auto-expands to 4 moves per promotion square).
- `game_state.dart` — Legal move filtering (pseudo-legal minus moves that leave king in check), `makeMove()`, `undo()`, check/checkmate/stalemate detection, all draw rules, position key for repetition detection.

### Phase 2 — Basic Board UI ✅
- `chess_board.dart` — Unicode piece rendering, tap-to-move, legal move dots/capture rings, last-move highlighting, promotion dialog
- `game_screen.dart` — Turn indicator, check display, undo button, game-over dialog with "New Game" option
- `main.dart` — Wired to `SetupScreen`

### Phase 3 — Undo ✅
- Implemented inside `game_state.dart` via `_history` stack of board snapshots
- Undo button in `game_screen.dart` AppBar, disabled when nothing to undo

### Phase 4 — Time Controls ✅
- `clock.dart` — Per-player time container: `whiteRemaining`, `blackRemaining`, `switchPlayer()`, `decrement()`, `resetClocks()`, `hasTimeLeft()`. Uses `Duration.zero` as the unlimited sentinel.
- `time_control.dart` — `TimeControlMode` enum: `unlimited`, `fiveMinutes`, `tenMinutes`
- `setup_screen.dart` — Player picks time mode, navigates to `GameScreen` passing chosen `Duration` and `TimeControlMode`
- `game_screen.dart`:
  - `Timer.periodic` ticks every second, decrements active player's clock
  - `_clockSnapshots` list saves `(whiteRemaining, blackRemaining)` before every move for undo restoration
  - `WidgetsBindingObserver` pauses clock on app background, resumes on foreground
  - `_gameOver` bool prevents timeout dialog from firing multiple times
  - Clock display in AppBar (turns red on timeout), undo restores clock snapshot
  - Board locked to square shape via `LayoutBuilder` + `SizedBox`

### Phase 5 — AI Opponent ✅
- `ai_engine.dart`:
  - `AiDifficulty` enum: `easy`, `medium`, `hard`
  - Negamax search with alpha-beta pruning, depths: Easy = 2, Medium = 3, Hard = 4
  - Easy mode has a 30% chance of playing a random legal move instead of the best one
  - Piece-square tables for positional scoring, plus standard material values
  - `AiEngine.getBestMove()` runs via `compute()` on a separate Isolate — UI never freezes
- `setup_screen.dart`:
  - `GameMode` enum (`twoPlayer` / `vsAi`) picker
  - Difficulty picker and "Play As" picker appear when vs-AI selected
- `game_screen.dart`:
  - `aiDifficulty` (null = 2-player) and `humanColor` params
  - `_isAiThinking` flag blocks board taps, shows "AI is thinking..." spinner
  - Minimum 2-second "thinking" delay via `Future.wait([...])`
  - Undo in vs-AI mode undoes both AI's move and human's move together
  - Captured pieces shown above/below board, derived live from `board.moveHistory`

### Phase 6 — Themes & Sound ✅

**Board Themes:**
- `board_theme.dart` — `BoardTheme` class (lightSquare, darkSquare, selectedSquare, lastMoveLight, lastMoveDark colors) + 4 presets: `classicGreen`, `brownWood`, `blueOcean`, `grayCoral`, collected in `BoardTheme.all`
- `theme_storage.dart` — Saves/loads the selected theme's **index** in `BoardTheme.all` via `shared_preferences` (key: `selected_board_theme_index`). ⚠️ **Important:** if `BoardTheme.all`'s order is ever changed/reordered, previously saved indices will point to the wrong theme. Don't reorder the list — only append new themes to the end.
- `chess_board.dart` — Takes a required `BoardTheme theme` param, uses it for all square/highlight colors instead of hardcoded values
- `setup_screen.dart` — Palette icon button in AppBar opens a dialog listing all themes with a 4-square color swatch preview and a checkmark on the current selection; loads saved theme on `initState`, saves immediately on selection
- `game_screen.dart` — Takes `boardTheme` param, passes to `ChessBoard`

**Sound Effects:**
- Sound files sourced as CC0/free-license from:
  - `move.wav` — Freesound.org, user mh2o, "chess_move_on_alabaster.wav" (CC0)
  - `capture.mp3` — Freesound.org, user el_boss, "Piece Placement.mp3" (CC0)
  - `check.ogg` — Kenney.nl "UI Audio" pack (CC0, no attribution needed)
  - `game_end.ogg` — Kenney.nl "UI Audio" pack (CC0, no attribution needed)
- Stored in `assets/sounds/`, registered in `pubspec.yaml` under `flutter: assets:`
- `sound_manager.dart`:
  - One **persistent** `AudioPlayer` instance per sound type (not created fresh per play — this was the fix for delay/dropout issues, see Common Issues table)
  - `SoundManager.init()` called once at app startup (in `main.dart`) to set `PlayerMode.lowLatency` on all 4 players ahead of time
  - Each play call does `player.stop()` then `player.play(AssetSource(...))` — this is the reliable pattern; an earlier `seek()`+`resume()` approach silently failed on-device and produced no sound at all
  - `SoundManager.enabled` bool flag exists for a future mute toggle (not yet wired to any UI)
- `main.dart` — `main()` is now `async`, calls `WidgetsFlutterBinding.ensureInitialized()` then `await SoundManager.init()` before `runApp()`
- `game_screen.dart` — `_playSoundFor(Move move)` helper: plays capture sound if `move.isCapture`, else plain move sound; additionally plays check sound if the move puts the opponent in check. Called after both human moves (`_attemptMove`) and AI moves (`_triggerAiMove`). `SoundManager.playGameEnd()` called in both `_checkTimeout()` and `_checkGameOver()`.

---

## Verified Working (manual testing on device)
- Legal move highlights appear on tap ✅
- Turn switches correctly after each move ✅
- Undo steps back correctly, restores clock time ✅
- CHECK indicator appears when king is in check ✅
- King can castle (kingside and queenside) ✅
- Pawn promotion dialog appears and works ✅
- Board renders cleanly, square-shaped ✅
- Setup screen: game mode, difficulty, play-as-color, time control, theme all selectable ✅
- 5-min and 10-min clocks count down per player, pause when app backgrounded ✅
- Timeout ends the game with a dialog (fires once only) ✅
- Unlimited mode shows --:-- and never times out ✅
- AI makes legal moves at all 3 difficulty levels, doesn't freeze UI ✅
- AI move always takes at least ~2 seconds ✅
- Undo in vs-AI mode correctly undoes both AI + human moves together ✅
- Captured pieces display above/below board, updates correctly through undo ✅
- Board theme picker works, selection persists after closing/reopening the app ✅
- All 4 sound effects (move/capture/check/game-end) play correctly and reliably, even on rapid move sequences ✅

---

## Board Coordinate Convention (IMPORTANT)
- `row 0` = rank 8 (black's back rank, top of screen)
- `row 7` = rank 1 (white's back rank, bottom of screen)
- `col 0` = file a (left), `col 7` = file h (right)
- White pieces move in the `-1` row direction (toward row 0)
- Black pieces move in the `+1` row direction (toward row 7)

---

## Current Project Status

**All originally-scoped must-have features are complete**, plus a custom app icon. The app is a fully playable, offline chess game with legal move enforcement, check/checkmate/stalemate/draw detection, undo, time controls, an AI opponent with 3 difficulty levels, board themes, sound effects, and a custom launcher icon — all verified working on the actual test device (Redmi Note 10 Pro).

### App Icon ✅
- Custom pawn-silhouette icon designed (cream-white pawn on dark green background, subtle diagonal checker accent), matching the app's Classic Green theme color
- Source image: `assets/icon/app_icon.png` (1024x1024)
- `flutter_launcher_icons` package (dev dependency) used to generate both standard and Android adaptive icons
- Config added to `pubspec.yaml`:
  ```yaml
  flutter_launcher_icons:
    android: true
    ios: false
    image_path: "assets/icon/app_icon.png"
    min_sdk_android: 21
    adaptive_icon_background: "#2D6A4F"
    adaptive_icon_foreground: "assets/icon/app_icon.png"
  ```
- Generated via `flutter pub run flutter_launcher_icons` — this also auto-created a missing `colors.xml` in the Android project for the adaptive icon background
- Verified showing correctly on Redmi Note 10 Pro home screen after full reinstall (`flutter run` after quitting the previous session — icon changes require a fresh install, not hot reload)

## Possible Next Steps (not yet decided/scoped)

1. **Polish pass** — bug hunting, edge case testing (e.g. underpromotion edge cases, simultaneous check+timeout races)
2. **Phase 7 — Online Multiplayer** — originally deferred as "maybe later," not a hard requirement. Would need architecture decisions (peer-to-peer vs. server-based, how offline-first app handles connectivity, etc.) — not yet scoped in any spec session.
3. **Settings/mute toggle** — `SoundManager.enabled` flag already exists in code but has no UI control yet; would be a small addition if wanted.

---

## Key Files — Full Source Code
All source files are on GitHub (private repo, pushed incrementally after each phase).

**pubspec.yaml dependencies:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  audioplayers: ^6.1.0
  shared_preferences: ^2.3.2
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_launcher_icons: ^0.14.4

flutter:
  uses-material-design: true
  assets:
    - assets/sounds/

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#2D6A4F"
  adaptive_icon_foreground: "assets/icon/app_icon.png"
```

---

## Workflow Rules (follow these when continuing)
1. Always confirm before doing — summarize the plan, wait for approval
2. One task at a time — don't jump ahead
3. Flag confusion early — ask before assuming
4. No surprise rewrites — only change what was agreed on
5. Always `Ctrl+K S` (save all files) before running `flutter run`
6. Always full-replace files rather than partial edits to avoid bracket mismatches
7. After each phase, commit to GitHub: `git add . && git commit -m "Phase X" && git push`
8. When a design decision could bite us later (e.g. index-based storage tied to list order), write it down in this doc immediately as a note, not just in chat
9. App icon changes require a full reinstall (uninstall + `flutter run`), not hot reload — Android caches launcher icons aggressively

---

## Common Issues & Solutions Encountered

| Problem | Solution |
|---|---|
| Build failing with "Type not found" | Files had unsaved changes — press `Ctrl+K S` to save all |
| Old counter app showing on phone | Build was failing silently — fix compile errors first |
| Two white lines on board | Replaced `Container` with `SizedBox.expand` + `ColoredBox` + `StackFit.expand` |
| `print()` not showing in terminal | MIUI filters logcat — use UI display for debug output instead |
| Two app processes running (two PIDs) | Full quit (`q`) then fresh `flutter run`, not hot restart |
| Board rendering as rectangle | Wrapped `ChessBoard` in `LayoutBuilder` + `SizedBox` with width == height == `constraints.maxWidth` |
| Timeout dialog firing multiple times | Added `_gameOver` bool flag; cancel timer before showing dialog |
| Sound delayed / sometimes missing on rapid moves | Creating a fresh `AudioPlayer` per play call has too much overhead. Fixed by using one **persistent** `AudioPlayer` per sound type, set to `PlayerMode.lowLatency`, reused across all plays |
| Sound stopped working entirely after first low-latency attempt | `seek()` immediately after `setSource()` fails silently in low-latency mode on-device. Fixed by using `player.stop()` then `player.play(AssetSource(...))` each time instead of `seek()`+`resume()` |
| `flutter pub get` didn't error but package "not found" when running it | pubspec.yaml edit wasn't saved (`Ctrl+K S`) before running the command — Flutter read the old file from disk |
| Missing `colors.xml` warning during icon generation | Not an error — `flutter_launcher_icons` auto-creates it when missing (needed for adaptive icon background color) |

---

## Notes / Gotchas to Keep in Mind

- **`BoardTheme.all` order is load-bearing.** The saved theme preference is just an integer index into this list. Never reorder or remove entries — only append new ones at the end, or saved preferences on real devices will silently point to the wrong theme.
- **Sound files are mixed formats** (`.wav`, `.mp3`, `.ogg`) — this is fine, `audioplayers` handles all of them via `AssetSource`, no need to standardize format.
- **Provider dependency is installed but unused so far.** All state currently lives in `StatefulWidget`/`setState`. If the app grows more complex (e.g. multiplayer, more shared state), consider migrating to Provider then rather than continuing to add ad-hoc state.
- **App icon changes need a full reinstall, not hot reload.** Android launchers cache icons aggressively — always fully quit and re-run, or uninstall first if it still doesn't update.