# Chess Offline — Project Handoff Document

## Project Overview

An offline chess Android app built with Flutter/Dart for personal use.
- Play solo, vs AI bot, or vs a friend on the same device (pass-and-play)
- Fully offline, personal APK install (no Play Store)

---

## Tech Stack

- **Framework:** Flutter (Dart)
- **State management:** Provider (added to pubspec.yaml, not yet wired up)
- **Sound:** audioplayers (added to pubspec.yaml, not yet implemented)
- **Editor:** VS Code
- **Test device:** Redmi Note 10 Pro, Android 13, USB debugging
- **Dev machine:** Windows 11, Zyrex Ultera N100, 8GB RAM

---

## Agreed Features (from spec sessions)

### Must-have (all implemented unless noted)
- Legal move enforcement (castling, en passant, promotion) ✅
- Check / checkmate / stalemate detection ✅
- Basic board UI with unicode pieces ✅
- Tap-to-move with legal move highlights ✅
- Local two-player pass-and-play ✅
- Undo / move history ✅
- Draw rules: threefold repetition, 50-move rule, insufficient material ✅
- AI opponent with minimax + alpha-beta pruning (multiple difficulty levels) ❌ Phase 5
- Time controls: 5 min / 10 min / Unlimited ❌ Phase 4
- Board/piece themes ❌ Phase 6
- Sound effects ❌ Phase 6

### Nice-to-have (deferred)
- Online multiplayer ❌ Phase 7

### Time control rules (agreed in spec)
- Per-player countdown clocks
- Clock pauses when app is backgrounded
- Undo restores time spent on undone move
- Timeout = loss (unless opponent has insufficient material → draw)

### AI rules (agreed in spec)
- Minimax + alpha-beta pruning (NOT Stockfish)
- 2-3 difficulty levels controlled by search depth + randomness

---

## Project Structure

```
chess_offline/
  lib/
    main.dart
    core/
      move_generator.dart   ✅ complete
      game_state.dart       ✅ complete
    models/
      piece.dart            ✅ complete
      position.dart         ✅ complete
      move.dart             ✅ complete
      board.dart            ✅ complete
    state/                  (empty, for future provider state)
    ui/
      screens/
        game_screen.dart    ✅ complete
      widgets/
        chess_board.dart    ✅ complete
```

---

## Completed Phases

### Phase 0 — Project Scaffolding ✅
- Flutter project created: `chess_offline`
- Folder structure set up
- Dependencies added: `provider`, `audioplayers`
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
- `main.dart` — Wired to `GameScreen` directly

### Phase 3 — Undo ✅
- Implemented inside `game_state.dart` via `_history` stack of board snapshots
- Undo button in `game_screen.dart` AppBar, disabled when nothing to undo

---

## Verified Working (manual testing on device)
- Legal move highlights appear on tap ✅
- Turn switches correctly after each move ✅
- Undo steps back correctly ✅
- CHECK indicator appears when king is in check ✅
- King can castle (kingside and queenside) ✅
- Pawn promotion dialog appears and works ✅
- Board renders cleanly (white line artifact fixed with `SizedBox.expand` + `ColoredBox`) ✅

---

## Board Coordinate Convention (IMPORTANT)
- `row 0` = rank 8 (black's back rank, top of screen)
- `row 7` = rank 1 (white's back rank, bottom of screen)
- `col 0` = file a (left), `col 7` = file h (right)
- White pieces move in the `-1` row direction (toward row 0)
- Black pieces move in the `+1` row direction (toward row 7)

---

## Next Phase to Implement

### Phase 4 — Time Controls
Three files need to be created/modified:

**1. Create `lib/core/clock.dart`**
- Per-player countdown timer
- `start()`, `pause()`, `resume()`, `reset()`
- Callback when time runs out
- Track time spent per move (for undo time restoration)
- Pause when app goes to background (use `WidgetsBindingObserver`)

**2. Create `lib/ui/screens/setup_screen.dart`**
- Shown before `GameScreen`
- Player picks time mode: 5 min / 10 min / Unlimited
- Navigates to `GameScreen` passing the chosen time control

**3. Update `lib/ui/screens/game_screen.dart`**
- Display two clock widgets (one per player)
- Wire clock to `makeMove()` — switch active clock after each move
- Handle timeout: call game over if clock hits zero
- Undo restores the time saved before that move was made
- Pause/resume clock on app lifecycle changes

**4. Update `lib/main.dart`**
- Point `home:` to `SetupScreen()` instead of `GameScreen()`

---

### Phase 5 — AI Opponent (after Phase 4)
- Create `lib/core/ai_engine.dart`
- Minimax with alpha-beta pruning
- Piece-square evaluation tables for positional scoring
- Difficulty levels: Easy (depth 1-2 + randomness), Medium (depth 3), Hard (depth 4-5)
- Run on a separate `Isolate` so UI doesn't freeze during AI "think" time
- Add "vs AI" mode option to `SetupScreen`
- AI plays as Black by default

---

### Phase 6 — Themes & Sound (after Phase 5)
- Multiple board color themes (Classic green, Brown wood, Blue ocean, etc.)
- Multiple piece sets (unicode symbols already in place, can add image-based sets)
- Sound effects via `audioplayers`: move, capture, check, game-end
- Settings screen to pick theme and toggle sound

---

### Phase 7 — Online Multiplayer (deferred, much later)
- Not planned for near future

---

## Key Files — Full Source Code

All source files are on GitHub at the repo pushed during this session.
The commit message was **"Phase 0 and Phase 1"** (note: Phases 2 and 3 were
added in the same session but may have been pushed under the same commit or a
follow-up — check the repo for latest state).

**pubspec.yaml dependencies to confirm are present:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  audioplayers: ^6.1.0
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

---

## Common Issues & Solutions Encountered

| Problem | Solution |
|---|---|
| Build failing with "Type not found" | Files had unsaved changes — press `Ctrl+K S` to save all |
| Old counter app showing on phone | Build was failing silently — fix compile errors first |
| Two white lines on board | Replaced `Container` with `SizedBox.expand` + `ColoredBox` + `StackFit.expand` |
| `print()` not showing in terminal | MIUI filters logcat — use UI display for debug output instead |
| Two app processes running (two PIDs) | Full quit (`q`) then fresh `flutter run`, not hot restart |
