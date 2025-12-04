# Chess Puzzle Solver - Product Requirements Document

## Overview

A chess puzzle game built in Godot Engine where players solve checkmate-in-1 to checkmate-in-5 puzzles sourced from the Lichess puzzle database. The game presents positions where the player must find the forced mating sequence.

**Platform Scope:**
- **v1.0:** Desktop only (Windows, macOS, Linux)
- **Future:** Mobile support requires architectural changes (see Engine Integration)

## Goals

- Provide an engaging chess puzzle experience with thousands of puzzles
- Support difficulty progression from beginner to advanced
- Track player performance and improvement over time
- Clean, responsive UI that works on desktop (with potential mobile export later)

---

## Data Source

### Lichess Puzzle Database

- **URL:** https://database.lichess.org/#puzzles
- **Format:** CSV (gzip compressed)
- **Size:** ~4 million puzzles, ~300MB compressed

### Puzzle CSV Schema

| Field | Description |
|-------|-------------|
| PuzzleId | Unique identifier (e.g., "00008") |
| FEN | Board position in Forsyth-Edwards Notation |
| Moves | Solution in UCI format (e.g., "e2e4 e7e5 d1h5") |
| Rating | Puzzle difficulty (800-3000+) |
| RatingDeviation | Confidence in rating |
| Popularity | How often puzzle is played |
| NbPlays | Total play count |
| Themes | Space-separated tags (e.g., "mateIn2 short sacrifice") |
| GameUrl | Source game on Lichess |
| OpeningTags | Opening classification |

### Filtering Strategy

For this game, filter puzzles where `Themes` contains:
- `mateIn1` — Beginner, pattern recognition
- `mateIn2` — Intermediate, one opponent response to consider
- `mateIn3` — Advanced, 5 half-moves of calculation
- `mateIn4` — Expert, 7 half-moves, requires sustained focus
- `mateIn5` — Master, 9 half-moves, upper limit for standard play

**Optional Challenge Mode:** `mateIn6`, `mateIn7`, `mateIn8` (composed studies, very advanced)

This yields approximately 700,000+ puzzles for standard play (mate in 1-5).

#### Why Cap at Mate in 5?

- **Cognitive limit:** 9 half-moves is roughly the upper bound for enjoyable calculation
- **Real game frequency:** Mate-in-6+ puzzles are rarer and often from composed studies rather than real games
- **Session pacing:** Longer puzzles slow down the "solve and move on" rhythm that makes puzzle apps engaging
- **Player retention:** Most users (even strong players) find mate-in-6+ tedious rather than fun

### Mate Depth Validation (Preprocessing)

Lichess theme tags are crowd-sourced and occasionally incorrect. Validate during preprocessing:

```python
def validate_mate_depth(puzzle):
    """
    Verify that move count matches tagged mate depth.
    
    Expected: mate_in_N requires (2 * N - 1) half-moves
    - Mate in 1: 1 move
    - Mate in 2: 3 moves (player, opponent, player)
    - Mate in 3: 5 moves
    - Mate in 4: 7 moves
    - Mate in 5: 9 moves
    """
    moves = puzzle['Moves'].split()
    actual_move_count = len(moves)
    
    # Extract mate_in from themes
    mate_in = extract_mate_depth(puzzle['Themes'])
    if mate_in is None:
        return False, "No mate theme found"
    
    expected_move_count = 2 * mate_in - 1
    
    if actual_move_count != expected_move_count:
        return False, f"Move count mismatch: expected {expected_move_count}, got {actual_move_count}"
    
    return True, "Valid"
```

**Optional: Stockfish Verification (Recommended)**

Move count validation is a sanity check, but Stockfish verification is the source of truth:

```python
def validate_with_engine(puzzle, engine):
    """
    Use Stockfish to confirm the position actually forces mate in N.
    More accurate than move counting, catches edge cases.
    """
    mate_in = extract_mate_depth(puzzle['Themes'])
    board = chess.Board(puzzle['FEN'])
    
    # Analyze with sufficient depth
    info = engine.analyse(board, chess.engine.Limit(depth=mate_in * 2 + 10))
    score = info["score"].relative
    
    if not score.is_mate():
        return False, "No forced mate found by engine"
    
    engine_mate = score.mate()
    if engine_mate != mate_in:
        return False, f"Engine says mate in {engine_mate}, tagged as {mate_in}"
    
    return True, "Verified"

# Usage in preprocessing pipeline
def preprocess_puzzle(puzzle, engine=None):
    # Step 1: Basic validation (fast)
    valid, msg = validate_mate_depth(puzzle)
    if not valid:
        return None, msg
    
    # Step 2: Engine verification (optional, slower but more accurate)
    if engine:
        valid, msg = validate_with_engine(puzzle, engine)
        if not valid:
            return None, msg
    
    return puzzle, "OK"
```

**Note:** Engine verification adds significant preprocessing time (~100ms per puzzle). Consider running it only on a sample or enabling it as a flag.

**Action:** Discard or re-tag puzzles that fail validation. Log mismatches for review.

---

## Engine Integration (Stockfish)

### Overview

The game uses Stockfish for two critical functions:
1. **Move Validation** — Accept any player move that maintains forced mate in ≤N moves
2. **Opponent Response** — Play the best defensive move after each player move

This approach eliminates false negatives (rejecting valid alternate solutions) and ensures the opponent always plays optimally.

### Platform Considerations

| Platform | Approach | Status |
|----------|----------|--------|
| Windows | `OS.create_process()` + UCI | ✅ v1.0 |
| macOS | `OS.create_process()` + UCI (requires signing) | ✅ v1.0 |
| Linux | `OS.create_process()` + UCI | ✅ v1.0 |
| iOS | **Cannot spawn processes** — requires GDExtension | ❌ Future |
| Android | GDExtension recommended | ❌ Future |
| Web | WASM Stockfish or server API | ❌ Future |

**Critical iOS Limitation:** Apple prohibits spawning external executables via `OS.create_process()`. Mobile support requires compiling Stockfish as a C++ library and linking via GDExtension.

### Architecture (Abstraction Layer)

To support future mobile platforms, use an abstract interface:

```gdscript
# engine_interface.gd (abstract base)
class_name EngineInterface
extends Node

signal analysis_complete(result: Dictionary)
signal ready

func analyze_position(fen: String, depth: int = 15) -> Dictionary:
    push_error("Not implemented")
    return {}

func get_best_move(fen: String) -> String:
    push_error("Not implemented")
    return ""

func is_mate_in_n(fen: String, n: int) -> bool:
    push_error("Not implemented")
    return false
```

```gdscript
# stockfish_process.gd (Desktop implementation)
class_name StockfishProcess
extends EngineInterface

# Uses OS.create_process() for desktop platforms
# ... implementation below ...
```

```gdscript
# stockfish_gdextension.gd (Future mobile implementation)
class_name StockfishGDExtension
extends EngineInterface

# Uses native C++ binding via GDExtension
# To be implemented for iOS/Android support
```

```gdscript
# In game_manager.gd (autoload)
func _ready():
    if OS.get_name() in ["Windows", "macOS", "Linux"]:
        engine = StockfishProcess.new()
    else:
        push_error("Platform not supported for engine integration")
        # Future: engine = StockfishGDExtension.new()
    add_child(engine)
```

### Why Runtime Validation?

| Approach | Pros | Cons |
|----------|------|------|
| Strict Lichess matching | Simple | Rejects valid alternate mates |
| Pre-compute all lines | Fast runtime | Complex preprocessing, DB bloat |
| **Runtime Stockfish** | Always correct, accepts all valid lines | Requires bundled engine |

For mate puzzles specifically, engine evaluation is **fast** (~10-50ms) because forced mates are trivial to detect.

### Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Godot Game                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ ChessBoard  │───▶│   Puzzle    │───▶│   Engine    │     │
│  │   (UI)      │    │ Controller  │    │  Interface  │     │
│  └─────────────┘    └─────────────┘    └──────┬──────┘     │
│                                               │             │
│                                    ┌──────────┴──────────┐  │
│                                    │                     │  │
│                              ┌─────▼─────┐    ┌─────────▼─┐│
│                              │ Stockfish │    │  Future   ││
│                              │  Process  │    │GDExtension││
│                              │ (Desktop) │    │ (Mobile)  ││
│                              └─────┬─────┘    └───────────┘│
└────────────────────────────────────┼───────────────────────┘
                                     │ UCI Protocol
                                     │ (stdin/stdout)
                                     ▼
                         ┌─────────────────────┐
                         │  Stockfish Binary   │
                         │  (bundled with app) │
                         └─────────────────────┘
```

### Threading & Responsiveness

**Critical:** Engine analysis must run in a background thread to prevent UI freezing.

```gdscript
class_name StockfishProcess
extends EngineInterface

var process_id: int = -1
var analysis_thread: Thread
var is_analyzing: bool = false

signal thinking_started
signal thinking_finished

func analyze_position_async(fen: String, depth: int = 15) -> Dictionary:
    is_analyzing = true
    emit_signal("thinking_started")
    
    # Start background thread
    analysis_thread = Thread.new()
    var result_container = {"result": null}
    analysis_thread.start(_analyze_thread.bind(fen, depth, result_container))
    
    # Check if taking too long (show spinner after 150ms)
    var start_time = Time.get_ticks_msec()
    while analysis_thread.is_alive():
        await get_tree().process_frame
        if Time.get_ticks_msec() - start_time > 150:
            # UI should show "thinking" indicator
            pass
    
    analysis_thread.wait_to_finish()
    is_analyzing = false
    emit_signal("thinking_finished")
    
    return result_container.result

func _analyze_thread(fen: String, depth: int, result_container: Dictionary):
    # Run analysis (blocking, but in background thread)
    result_container.result = _analyze_sync(fen, depth)
```

**UI Response:**
- Connect to `thinking_started` / `thinking_finished` signals
- Show subtle spinner or "thinking..." text if analysis exceeds 150ms
- Never block main thread

### Stockfish Bridge Implementation (`stockfish_process.gd`)

```gdscript
class_name StockfishProcess
extends EngineInterface

var process_id: int = -1
var stdin: FileAccess
var stdout: FileAccess

func _ready():
    _start_engine()
    emit_signal("ready")

func _start_engine():
    # Path to bundled Stockfish binary
    var stockfish_path = _get_stockfish_path()
    
    var args = []
    process_id = OS.create_process(stockfish_path, args)
    # Set up pipe communication...

func _get_stockfish_path() -> String:
    var base = OS.get_executable_path().get_base_dir()
    match OS.get_name():
        "Windows":
            return base + "/bin/stockfish/windows/stockfish.exe"
        "macOS":
            return base + "/bin/stockfish/macos/stockfish"
        "Linux":
            return base + "/bin/stockfish/linux/stockfish"
    return ""

func _analyze_sync(fen: String, depth: int) -> Dictionary:
    """
    Synchronous analysis (call from thread only).
    
    Returns: {
        "score": int or null,
        "mate_in": int or null,  # Positive = current player mates, negative = opponent mates
        "best_move": String (UCI format)
    }
    """
    _send_command("position fen " + fen)
    _send_command("go depth " + str(depth))
    return _parse_analysis()

func get_best_move(fen: String) -> String:
    """Returns best move in UCI format (e.g., 'e2e4')"""
    var result = await analyze_position_async(fen, 15)
    return result.best_move

func is_mate_in_n(fen: String, n: int) -> bool:
    """Check if position has forced mate in exactly N moves for side to move"""
    var result = await analyze_position_async(fen, n * 2 + 5)  # Extra depth for safety
    return result.mate_in != null and result.mate_in <= n and result.mate_in > 0

func _send_command(cmd: String):
    # Write to stdin...
    pass

func _parse_analysis() -> Dictionary:
    # Parse UCI output like "info depth 15 score mate 2 ..." 
    # and "bestmove e2e4"
    pass

func _exit_tree():
    if process_id != -1:
        OS.kill(process_id)
```

### Performance Expectations

| Operation | Expected Latency | Notes |
|-----------|------------------|-------|
| Mate-in-1 validation | <20ms | Trivial for engine |
| Mate-in-2 validation | 20-50ms | Still fast |
| Mate-in-3 validation | 30-80ms | Acceptable |
| Mate-in-5 validation | 50-200ms | May show spinner on slow hardware |
| Best move calculation | 30-100ms | Depends on position complexity |

**Note:** Open positions with many legal moves take longer. Always use threading.

### Bundling Stockfish

**Binary sources:**
- Official: https://stockfishchess.org/download/
- Needed builds: Windows (x64), macOS (x64, ARM), Linux (x64)

**Project structure:**
```
bin/
└── stockfish/
    ├── windows/
    │   └── stockfish.exe
    ├── macos/
    │   └── stockfish          # Universal binary (x64 + ARM)
    └── linux/
        └── stockfish
```

**macOS Code Signing Requirement:**
- The bundled Stockfish binary **must** be signed with your Apple Developer certificate
- Without signing, macOS Gatekeeper will block execution as "unverified developer"
- Add to your export workflow: `codesign --deep --force --sign "Developer ID" stockfish`
- If using App Sandbox, add entitlement: `com.apple.security.cs.allow-unsigned-executable-memory`

**Export configuration:** Include appropriate binary based on target platform.

---

## Game Modes

### 1. Practice Mode (Default)

**Concept:** No pressure, no penalties—just solve puzzles at your own pace.

| Setting | Options |
|---------|---------|
| Mate Depth | 1 / 2 / 3 / 4 / 5 / All |
| Rating Range | 400 - 3000 (slider) |
| Order | Random / Progressive (ascending by rating) |

**Behavior:**
- Incorrect moves allowed with retry
- Hints and solution available anytime
- No time limit
- Stats tracked but no "game over" state
- Skip puzzles freely

**Use case:** Learning, warming up, casual play.

---

### 2. Sprint Mode

**Concept:** Solve as many puzzles as possible within a time limit. Three strikes and you're out.

| Setting | Options |
|---------|---------|
| Time Limit | 1 min / 3 min / 5 min |
| Mate Depth | 1 / 2 / 3 / 4 / 5 / All |
| Rating Range | Fixed by difficulty preset (Easy/Medium/Hard) or custom |

**Rules:**
- Timer starts on first puzzle load
- Correct solution → +1 point, next puzzle immediately
- Incorrect move → +1 strike (max 3), puzzle resets, can retry
- 3 strikes OR timer expires → game over
- No hints, no solution reveal during game

**Scoring:**
- Primary: Puzzles solved count
- Secondary: Accuracy percentage
- Tiebreaker: Average time per puzzle

**End Screen Shows:**
- Puzzles solved
- Strikes used
- Accuracy (solves / attempts)
- Time remaining (if struck out early)

**Why it works:**
- Simple to understand
- High replayability ("one more run")
- Natural leaderboard metric
- Time pressure creates excitement

---

### 3. Streak Mode

**Concept:** Solve puzzles of increasing difficulty. One wrong move ends your run.

| Setting | Options |
|---------|---------|
| Starting Difficulty | Beginner (800) / Intermediate (1200) / Advanced (1600) / Expert (2000) / Custom |
| Mate Depth | 1 / 2 / 3 / 4 / 5 / All |

**Rules:**
- First puzzle at starting rating
- Each solve → next puzzle is +25 to +50 rating higher
- First incorrect move → game over (no retries)
- No hints, no solution reveal during game
- No time limit per puzzle

**Difficulty Progression Example (starting at 1200):**
```
Puzzle 1: 1200
Puzzle 2: 1235
Puzzle 3: 1270
Puzzle 4: 1310
...
Puzzle 20: 1850
```

**Scoring:**
- Primary: Streak count (puzzles solved)
- Secondary: Peak rating reached
- Badge thresholds: 5 / 10 / 15 / 20 / 25 / 30

**End Screen Shows:**
- Streak count
- Starting rating → Peak rating reached
- The puzzle that ended the run (with solution)

**Why it works:**
- High stakes create tension
- "One more try" addiction loop
- Starting difficulty selector makes it accessible to all skill levels
- Peak rating is a satisfying metric to chase

---

### 4. Daily Challenge

**Concept:** Five puzzles, same for everyone each day. One attempt per puzzle. Compare scores.

**Puzzle Selection (Deterministic):**

⚠️ **Critical:** Godot's `seed()` does NOT affect SQLite's `RANDOM()`. They use separate RNG systems.

**Correct approach — Hash-based selection:**

```gdscript
const DAILY_RATING_BRACKETS = [
    {"min": 800, "max": 1000},   # Puzzle 1: Warm-up
    {"min": 1000, "max": 1300},  # Puzzle 2: Easy
    {"min": 1300, "max": 1600},  # Puzzle 3: Medium
    {"min": 1600, "max": 1900},  # Puzzle 4: Hard
    {"min": 1900, "max": 2200},  # Puzzle 5: Challenge
]

func get_daily_puzzles() -> Array[PuzzleData]:
    var date = Time.get_date_dict_from_system()
    var date_string = "%04d-%02d-%02d" % [date.year, date.month, date.day]
    
    var puzzles: Array[PuzzleData] = []
    
    for i in range(5):
        var bracket = DAILY_RATING_BRACKETS[i]
        var puzzle = _get_deterministic_puzzle(date_string, i, bracket.min, bracket.max)
        puzzles.append(puzzle)
    
    return puzzles

func _get_deterministic_puzzle(date_string: String, index: int, min_rating: int, max_rating: int) -> PuzzleData:
    # Get all puzzle IDs in this rating bracket
    var query = "SELECT id FROM puzzles WHERE rating BETWEEN ? AND ? AND mate_in <= 5"
    var ids = db.execute(query, [min_rating, max_rating])
    
    # Hash each ID with the date to get a deterministic "score"
    var scored_ids = []
    for row in ids:
        var puzzle_id = row["id"]
        var hash_input = date_string + "-" + str(index) + "-" + puzzle_id
        var score = hash(hash_input)
        scored_ids.append({"id": puzzle_id, "score": score})
    
    # Sort by score and take the first one
    scored_ids.sort_custom(func(a, b): return a.score < b.score)
    var selected_id = scored_ids[0].id
    
    # Fetch full puzzle data
    return db.get_puzzle_by_id(selected_id)
```

**Why hash-based selection?**
- Godot's `hash()` is deterministic across all platforms
- Same date = same puzzles for all players worldwide
- Stable even if database rows are added/removed (based on puzzle ID, not row offset)
- No external server required

**Alternative (more efficient for large DBs):**

```gdscript
func _get_deterministic_puzzle_fast(date_string: String, index: int, min_rating: int, max_rating: int) -> PuzzleData:
    # Seed Godot's RNG with date hash
    var seed_value = hash(date_string + "-" + str(index))
    seed(seed_value)
    
    # Get count of puzzles in bracket
    var count = db.execute("SELECT COUNT(*) as c FROM puzzles WHERE rating BETWEEN ? AND ? AND mate_in <= 5", 
                           [min_rating, max_rating])[0]["c"]
    
    # Pick a deterministic offset using Godot's seeded RNG
    var offset = randi() % count
    
    # Fetch puzzle at that offset (stable if using ORDER BY id)
    var query = """
        SELECT * FROM puzzles 
        WHERE rating BETWEEN ? AND ? AND mate_in <= 5
        ORDER BY id
        LIMIT 1 OFFSET ?
    """
    return db.execute(query, [min_rating, max_rating, offset])[0]
```

**Note:** The `ORDER BY id` ensures consistent ordering. Never use `ORDER BY RANDOM()` for deterministic selection.

**Rules:**
- Same 5 puzzles for all players on a given day
- One attempt per puzzle (first move is final)
- No hints, no retries
- Must complete all 5 (can't skip)
- Available once per day (resets at midnight local time)

**Scoring:**
- 1 point per correct first move
- Bonus points for solving entire sequence without errors
- Max score: 5 points (+ bonus for perfect solves)

**Scoring Detail:**
| Result | Points |
|--------|--------|
| Solved on first move | 1 pt |
| Perfect solve (no wrong moves in sequence) | +0.5 pt bonus |
| Failed puzzle | 0 pts |
| **Max possible** | **7.5 pts** |

**End Screen Shows:**
- Score breakdown per puzzle
- Total score
- "Share" button → copies result to clipboard:
  ```
  Chess Puzzles Daily #127
  ⬛🟩🟩⬛🟩 (3/5)
  🔥 Streak: 2
  ```

**Why it works:**
- Habit formation (daily ritual)
- Social/shareable (Wordle-style)
- No server needed (deterministic seed)
- Fixed difficulty curve = fair comparison

---

### Mode Comparison Matrix

Quick reference for mode-specific behaviors:

| Feature | Practice | Sprint | Streak | Daily |
|---------|----------|--------|--------|-------|
| **Hints available** | ✅ | ❌ | ❌ | ❌ |
| **Solution reveal** | ✅ | ❌ | ❌ | After attempt |
| **Retry wrong move** | ✅ Rewind 1 ply | ✅ Restart puzzle (+strike) | ❌ Game over | ❌ Puzzle failed |
| **Skip puzzle** | ✅ | ❌ | ❌ | ❌ |
| **Time pressure** | ❌ | ✅ | ❌ | ❌ |
| **Strike system** | ❌ | ✅ (3 strikes) | ❌ | ❌ |
| **One-shot moves** | ❌ | ❌ | ✅ | ✅ |
| **Difficulty selection** | Manual | Preset or custom | Starting rating | Fixed curve |
| **Difficulty progression** | None | Fixed | +25-50 rating/solve | Fixed per puzzle |
| **Stats tracked** | ✅ | ✅ | ✅ | ✅ |
| **Replay last puzzle** | ✅ | ✅ | ✅ | ✅ (after completion) |

### Mid-Puzzle Blunder Behavior

What happens when a player makes the correct first move(s) but blunders later in the sequence:

| Mode | First Move Correct → Later Move Wrong | Behavior |
|------|---------------------------------------|----------|
| **Practice** | Rewind to position before wrong move | Forgiving — lets player learn |
| **Sprint** | +1 Strike, restart puzzle from beginning | Prevents guess-and-check gaming |
| **Streak** | Immediate game over | High stakes — one mistake ends run |
| **Daily** | Puzzle marked as failed, proceed to next | No retries — every move matters |

**Rationale:**
- Practice is for learning, so allow granular retries
- Sprint/Streak need to prevent gaming via trial-and-error
- Daily maintains fairness across all players

---

## Features

### MVP (Version 1.0)

1. **Game Modes** (see Game Modes section above)
   - Practice Mode
   - Sprint Mode
   - Streak Mode
   - Daily Challenge

2. **Puzzle Display**
   - Render chess board (8x8 grid)
   - Display pieces from FEN position
   - Board orientation based on side to move
   - Highlight last opponent move (the move that sets up the puzzle)

3. **Move Input**
   - Click-to-select piece, click-to-move (two-click system)
   - Drag-and-drop alternative
   - Highlight legal move squares for selected piece
   - Pawn promotion dialog when applicable
   - Auto-promote to Queen setting (default ON for Sprint/Streak modes)
   - "Thinking" indicator when engine analysis exceeds 150ms

4. **Puzzle Flow**
   - Load puzzle from database
   - Player makes move
   - If correct: auto-play opponent response, continue until mate
   - If incorrect: behavior depends on mode (retry, strike, or game over)
   - On completion: mode-specific feedback and next action

5. **Puzzle Selection**
   - Filter by mate depth (1 through 5, or all)
   - Filter by rating range
   - Random puzzle within filters
   - Mode-specific selection (progressive for streak, seeded for daily)

6. **Stats Tracking**
   - Per-mode statistics
   - Overall puzzles solved
   - Streaks and high scores

### Version 1.1 (Post-MVP)

- Player rating system (Glicko-2 or simplified ELO)
- Progressive hint system (highlight piece → highlight square → show move)
- Puzzle history / review failed puzzles
- Sound effects and animations
- Theme customization (board colors, piece sets)

### Version 2.0 (Future)

- Online leaderboards
- Custom puzzle collections
- Puzzle editor
- Opening/endgame trainer modes
- Bounty Hunt mode (points scale with mate depth)
- Theme Focus mode (back-rank mates, queen sacrifices, etc.)

---

## Technical Architecture

### Project Structure

```
chess_puzzles/
├── project.godot
├── assets/
│   ├── pieces/              # Piece sprites (PNG)
│   │   ├── white_king.png
│   │   ├── white_queen.png
│   │   ├── ... (12 pieces total)
│   ├── board/
│   │   ├── light_square.png
│   │   ├── dark_square.png
│   │   └── highlight.png
│   ├── ui/
│   │   └── ... (buttons, icons)
│   └── audio/
│       └── ... (move sounds, success/fail)
├── bin/
│   ├── stockfish/           # Platform-specific Stockfish binaries
│   │   ├── windows/
│   │   │   └── stockfish.exe
│   │   ├── macos/
│   │   │   └── stockfish
│   │   └── linux/
│   │       └── stockfish
├── data/
│   ├── puzzles.db           # SQLite database (puzzles + user history)
│   └── user_stats.json      # Lightweight aggregate stats
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd       # Global state, mode management
│   │   ├── chess_logic.gd        # Move validation, FEN parsing
│   │   ├── stockfish_bridge.gd   # UCI engine communication
│   │   └── user_data.gd          # Stats, settings persistence
│   ├── board/
│   │   ├── chess_board.gd        # Board rendering and interaction
│   │   ├── square.gd             # Individual square behavior
│   │   └── piece.gd              # Piece sprite and drag behavior
│   ├── puzzle/
│   │   ├── puzzle_controller.gd  # Puzzle state machine (all modes)
│   │   ├── puzzle_data.gd        # Puzzle data class
│   │   ├── puzzle_validator.gd   # Stockfish-based move validation
│   │   └── daily_generator.gd    # Deterministic daily puzzle selection
│   ├── modes/
│   │   ├── practice_mode.gd      # Practice mode logic
│   │   ├── sprint_mode.gd        # Sprint timer + strikes logic
│   │   ├── streak_mode.gd        # Streak progression logic
│   │   └── daily_mode.gd         # Daily challenge logic
│   └── ui/
│       ├── main_menu.gd
│       ├── mode_setup.gd         # Generic mode setup screen
│       ├── puzzle_hud.gd         # Mode-aware in-puzzle HUD
│       ├── game_over_screen.gd   # Mode-specific end screens
│       ├── settings_menu.gd
│       └── stats_screen.gd
├── scenes/
│   ├── main.tscn
│   ├── board/
│   │   ├── chess_board.tscn
│   │   ├── square.tscn
│   │   └── piece.tscn
│   ├── ui/
│   │   ├── main_menu.tscn
│   │   ├── practice_setup.tscn
│   │   ├── sprint_setup.tscn
│   │   ├── streak_setup.tscn
│   │   ├── puzzle_screen.tscn
│   │   ├── promotion_dialog.tscn
│   │   ├── game_over_screen.tscn
│   │   ├── daily_complete.tscn
│   │   ├── stats_screen.tscn
│   │   ├── settings_menu.tscn
│   │   └── licenses_screen.tscn
│   └── components/
│       ├── timer_display.tscn
│       ├── strike_indicator.tscn
│       ├── streak_counter.tscn
│       ├── daily_progress.tscn
│       └── thinking_indicator.tscn  # Shows during engine analysis >150ms
├── tests/                        # Unit tests (GUT framework)
│   ├── test_fen_parser.gd
│   ├── test_move_generation.gd
│   ├── test_check_detection.gd
│   ├── test_checkmate_detection.gd
│   ├── test_special_moves.gd
│   ├── test_puzzle_validation.gd
│   └── test_stockfish_integration.gd
└── tools/                        # Preprocessing scripts (Python)
    ├── preprocess_puzzles.py     # Filter and validate Lichess CSV
    ├── requirements.txt          # Python dependencies (python-chess)
    └── README.md                 # Preprocessing instructions
```

### Core Systems

#### 1. Chess Logic (`chess_logic.gd`)

Autoloaded singleton handling all chess rules.

```gdscript
# Key responsibilities:
# - Parse FEN strings into board state
# - Generate legal moves for any position
# - Detect check, checkmate, stalemate
# - Validate move legality
# - Convert between notations (UCI, algebraic, internal)

class_name ChessLogic
extends Node

enum PieceType { NONE, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

var board: Array[int] = []  # 64 squares, 0 = empty
var side_to_move: PieceColor
var castling_rights: int
var en_passant_square: int
var halfmove_clock: int
var fullmove_number: int

func parse_fen(fen: String) -> void
func get_legal_moves(square: int) -> Array[int]
func is_move_legal(from: int, to: int) -> bool
func make_move(from: int, to: int, promotion: PieceType = PieceType.NONE) -> void
func is_in_check() -> bool
func is_checkmate() -> bool
func to_fen() -> String
func uci_to_squares(uci: String) -> Dictionary  # {"from": int, "to": int, "promotion": PieceType}
```

#### 2. Puzzle Controller (`puzzle_controller.gd`)

State machine managing puzzle flow across all game modes.

```gdscript
enum GameMode {
    PRACTICE,
    SPRINT,
    STREAK,
    DAILY
}

enum PuzzleState {
    LOADING,
    PLAYER_TURN,
    OPPONENT_TURN,
    COMPLETED_SUCCESS,
    COMPLETED_FAILED,
    SHOWING_SOLUTION,
    GAME_OVER
}

var current_mode: GameMode
var current_puzzle: PuzzleData
var current_state: PuzzleState
var solution_moves: Array[String]  # UCI moves
var move_index: int
var attempts: int

# Mode-specific state
var sprint_time_remaining: float
var sprint_strikes: int
var sprint_solved_count: int

var streak_count: int
var streak_current_rating: int
var streak_start_rating: int

var daily_puzzle_index: int
var daily_results: Array[bool]  # true = solved, false = failed
var daily_scores: Array[float]

signal puzzle_loaded(puzzle: PuzzleData)
signal move_made(from: int, to: int, is_correct: bool)
signal puzzle_completed(success: bool, attempts: int)
signal opponent_moving(from: int, to: int)
signal game_over(mode: GameMode, stats: Dictionary)
signal timer_updated(time_remaining: float)
signal strike_added(total_strikes: int)

func start_game(mode: GameMode, settings: Dictionary) -> void
func load_puzzle(puzzle: PuzzleData) -> void
func load_next_puzzle() -> void  # Mode-aware puzzle selection
func submit_move(from: int, to: int, promotion: PieceType = PieceType.NONE) -> bool
func show_hint() -> void  # Practice mode only
func show_solution() -> void  # Practice mode only
func skip_puzzle() -> void  # Practice mode only
func end_game() -> void

# Daily challenge helpers
func get_daily_seed() -> int
func get_daily_puzzles() -> Array[PuzzleData]
func is_daily_completed_today() -> bool
```

#### 3. Board Rendering (`chess_board.gd`)

Handles visual representation and input.

```gdscript
@export var square_size: int = 80
@export var light_color: Color = Color("#F0D9B5")
@export var dark_color: Color = Color("#B58863")
@export var highlight_color: Color = Color("#829769", 0.8)
@export var last_move_color: Color = Color("#CDD26A", 0.5)

var selected_square: int = -1
var legal_move_squares: Array[int] = []
var flipped: bool = false  # true = black perspective

signal square_clicked(square: int)
signal move_attempted(from: int, to: int)

func set_position(fen: String) -> void
func highlight_squares(squares: Array[int], color: Color) -> void
func show_last_move(from: int, to: int) -> void
func animate_move(from: int, to: int, duration: float = 0.2) -> void
func flip_board() -> void

# Input handling with flipped board support
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        var square = screen_to_board(event.position)
        emit_signal("square_clicked", square)

func screen_to_board(screen_pos: Vector2) -> int:
    """Convert screen coordinates to board square index (0-63)."""
    var local_pos = screen_pos - global_position
    var grid_x = int(local_pos.x / square_size)
    var grid_y = int(local_pos.y / square_size)
    
    # Clamp to valid range
    grid_x = clamp(grid_x, 0, 7)
    grid_y = clamp(grid_y, 0, 7)
    
    # Invert coordinates when board is flipped
    if flipped:
        grid_x = 7 - grid_x
        grid_y = 7 - grid_y
    
    return grid_y * 8 + grid_x

func board_to_screen(square: int) -> Vector2:
    """Convert board square index to screen coordinates (center of square)."""
    var grid_x = square % 8
    var grid_y = square / 8
    
    if flipped:
        grid_x = 7 - grid_x
        grid_y = 7 - grid_y
    
    return global_position + Vector2(
        grid_x * square_size + square_size / 2,
        grid_y * square_size + square_size / 2
    )
```

#### 4. Auto-Promotion Logic (`puzzle_controller.gd`)

Smart promotion handling for time-sensitive modes:

```gdscript
func handle_promotion(from: int, to: int) -> PieceType:
    """
    Determine promotion piece. Auto-promote to Queen in Sprint/Streak
    unless under-promotion is required for the winning line.
    """
    var dominated_mode = current_mode in [GameMode.SPRINT, GameMode.STREAK]
    
    if user_data.settings.auto_promote_queen and dominated_mode:
        # Try Queen first
        var queen_fen = chess_logic.apply_move(current_fen, from, to, PieceType.QUEEN)
        var moves_remaining = get_moves_remaining()
        
        if moves_remaining == 0:
            # Final move — check if Queen delivers mate
            if chess_logic.is_checkmate(queen_fen):
                return PieceType.QUEEN
        else:
            # Check if Queen maintains winning line
            if await engine.is_mate_in_n(queen_fen, moves_remaining):
                return PieceType.QUEEN
        
        # Queen doesn't work — try other pieces
        for piece in [PieceType.KNIGHT, PieceType.ROOK, PieceType.BISHOP]:
            var test_fen = chess_logic.apply_move(current_fen, from, to, piece)
            if moves_remaining == 0:
                if chess_logic.is_checkmate(test_fen):
                    return piece  # Auto-select winning under-promotion
            else:
                if await engine.is_mate_in_n(test_fen, moves_remaining):
                    return piece
        
        # No single winning promotion — fall through to dialog
    
    # Show promotion dialog (Practice mode, or ambiguous position)
    return await show_promotion_dialog()
```

#### 5. Data Layer

**Puzzle Database (SQLite via godot-sqlite plugin)**

```sql
-- Core puzzle storage
CREATE TABLE puzzles (
    id TEXT PRIMARY KEY,
    fen TEXT NOT NULL,
    moves TEXT NOT NULL,          -- Original Lichess solution (reference only)
    rating INTEGER NOT NULL,
    themes TEXT,
    mate_in INTEGER               -- Derived: 1, 2, 3, 4, 5, or 6+ (stored as 6)
);

CREATE INDEX idx_rating ON puzzles(rating);
CREATE INDEX idx_mate_in ON puzzles(mate_in);

-- User puzzle history (scalable - replaces JSON arrays)
CREATE TABLE user_puzzle_history (
    puzzle_id TEXT PRIMARY KEY,
    result TEXT NOT NULL,         -- 'solved', 'failed', 'skipped'
    mode TEXT NOT NULL,           -- 'practice', 'sprint', 'streak', 'daily'
    attempts INTEGER DEFAULT 1,
    solved_at DATETIME,
    time_spent_ms INTEGER
);

CREATE INDEX idx_history_result ON user_puzzle_history(result);
CREATE INDEX idx_history_mode ON user_puzzle_history(mode);
CREATE INDEX idx_history_solved_at ON user_puzzle_history(solved_at);
```

**Why SQLite for puzzle history?**
- JSON arrays become slow at 10k+ entries
- Enables fast queries: "random unsolved puzzle", "accuracy by rating range"
- Scales to 100k+ puzzles without performance degradation

**User Stats (JSON) — Lightweight aggregates only**

```json
{
    "player_rating": 1200,
    "total_puzzles_solved": 0,
    "total_time_played_seconds": 0,
    
    "practice": {
        "puzzles_solved": 0,
        "puzzles_attempted": 0,
        "current_streak": 0,
        "best_streak": 0,
        "solved_by_mate_depth": {
            "1": 0, "2": 0, "3": 0, "4": 0, "5": 0, "6+": 0
        }
    },
    
    "sprint": {
        "best_1min": 0,
        "best_3min": 0,
        "best_5min": 0,
        "total_runs": 0,
        "total_puzzles_solved": 0
    },
    
    "streak": {
        "best_streak": 0,
        "best_rating_reached": 0,
        "total_runs": 0,
        "total_puzzles_solved": 0
    },
    
    "daily": {
        "last_completed_date": null,
        "current_daily_streak": 0,
        "best_daily_streak": 0,
        "days_played": 0,
        "total_score": 0,
        "perfect_days": 0
    },
    
    "settings": {
        "sound_enabled": true,
        "show_legal_moves": true,
        "auto_flip_board": true,
        "auto_promote_queen": true,
        "animation_speed": 1.0
    }
}
```

**Querying unsolved puzzles:**
```gdscript
func get_random_unsolved_puzzle(min_rating: int, max_rating: int, mate_in: int) -> PuzzleData:
    var query = """
        SELECT p.* FROM puzzles p
        LEFT JOIN user_puzzle_history h ON p.id = h.puzzle_id
        WHERE p.rating BETWEEN ? AND ?
        AND p.mate_in = ?
        AND (h.result IS NULL OR h.result != 'solved')
        ORDER BY RANDOM()
        LIMIT 1
    """
    return db.execute(query, [min_rating, max_rating, mate_in])
```

---

## User Interface

### Screens

#### 1. Main Menu
- **Practice** → Puzzle selection options (default mode)
- **Sprint** → Time attack mode setup
- **Streak** → Endless increasing difficulty setup
- **Daily** → Today's 5-puzzle challenge
- **Stats** → Player statistics (all modes)
- **Settings** → Game options
- **Quit**

#### 2. Mode Setup Screens

**Practice Setup:**
- Mate depth selector (1 / 2 / 3 / 4 / 5 / All)
- Challenge mode toggle (enables mate in 6+)
- Rating range slider (400 - 3000)
- Mode toggle: Random / Progressive
- **Start** button

**Sprint Setup:**
- Time selector: 1 min / 3 min / 5 min
- Difficulty preset: Easy / Medium / Hard / Custom
- Mate depth filter (optional)
- **Start** button

**Streak Setup:**
- Starting difficulty: Beginner (800) / Intermediate (1200) / Advanced (1600) / Expert (2000) / Custom slider
- Mate depth filter (optional)
- **Start** button

**Daily Challenge:**
- No setup—immediately loads today's puzzles
- Shows "Already completed today" if done

#### 3. Puzzle Screen (Primary Gameplay)

**Practice Mode HUD:**
```
┌─────────────────────────────────────────┐
│  ← Back              Puzzle #1234       │
│                      Rating: 1450       │
├─────────────────────────────────────────┤
│                                         │
│         ┌─────────────────────┐         │
│         │                     │         │
│         │     CHESS BOARD     │         │
│         │      (8x8 grid)     │         │
│         │                     │         │
│         └─────────────────────┘         │
│                                         │
│  "White to move - Mate in 4"            │
│                                         │
├─────────────────────────────────────────┤
│   [Hint]     [Solution]     [Skip]      │
│                                         │
│   Streak: 5        Solved: 127          │
└─────────────────────────────────────────┘
```

**Sprint Mode HUD:**
```
┌─────────────────────────────────────────┐
│  ← Quit        ⏱️ 2:34        ❌❌⚪     │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│         ┌─────────────────────┐         │
│         │                     │         │
│         │     CHESS BOARD     │         │
│         │      (8x8 grid)     │         │
│         │                     │         │
│         └─────────────────────┘         │
│                                         │
│  "Mate in 2"                            │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│   Solved: 12       Rating: ~1400        │
└─────────────────────────────────────────┘
```

**Streak Mode HUD:**
```
┌─────────────────────────────────────────┐
│  ← Quit                     🔥 Streak: 8│
│                                         │
├─────────────────────────────────────────┤
│                                         │
│         ┌─────────────────────┐         │
│         │                     │         │
│         │     CHESS BOARD     │         │
│         │      (8x8 grid)     │         │
│         │                     │         │
│         └─────────────────────┘         │
│                                         │
│  "Mate in 3"          Rating: 1650      │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│   Started: 1200 → Current: 1650 (+450)  │
└─────────────────────────────────────────┘
```

**Daily Challenge HUD:**
```
┌─────────────────────────────────────────┐
│  ← Quit         Daily #127      3/5     │
│                 ⬛🟩🟩⚪⚪              │
├─────────────────────────────────────────┤
│                                         │
│         ┌─────────────────────┐         │
│         │                     │         │
│         │     CHESS BOARD     │         │
│         │      (8x8 grid)     │         │
│         │                     │         │
│         └─────────────────────┘         │
│                                         │
│  "Mate in 2"          Puzzle 4 of 5     │
│                       Rating: 1720      │
├─────────────────────────────────────────┤
│                                         │
│         ⚠️ One attempt per puzzle       │
└─────────────────────────────────────────┘
```

#### 4. Promotion Dialog
- Modal with 4 piece options (Queen, Rook, Bishop, Knight)
- Appears when pawn reaches final rank

#### 5. Puzzle Complete / Game Over Screens

**Practice Mode - Puzzle Complete:**
- Success: Checkmark, "+X rating", "Next Puzzle" button
- Failure: X mark, "Retry" / "Show Solution" / "Next" buttons

**Sprint Mode - Game Over:**
```
┌─────────────────────────────────────────┐
│            ⏱️ TIME'S UP!                │
│         (or STRUCK OUT! if 3 strikes)   │
├─────────────────────────────────────────┤
│                                         │
│         🏆 Puzzles Solved: 14           │
│                                         │
│         Accuracy: 82% (14/17)           │
│         Time: 3:00 / Strikes: 3         │
│                                         │
│         🥇 New Best! (was 12)           │
│                                         │
├─────────────────────────────────────────┤
│ [Replay Last] [Play Again] [Main Menu]  │
└─────────────────────────────────────────┘
```

**Streak Mode - Game Over:**
```
┌─────────────────────────────────────────┐
│            💔 STREAK ENDED              │
├─────────────────────────────────────────┤
│                                         │
│         🔥 Final Streak: 12             │
│                                         │
│         Started: 1200                   │
│         Peak: 1720 (+520)               │
│                                         │
│         🥇 New Record! (was 9)          │
│                                         │
│    ─────────────────────────────────    │
│    The puzzle that ended your run:      │
│    [Show Solution]  [Replay Puzzle]     │
│                                         │
├─────────────────────────────────────────┤
│   [Try Again]     [Main Menu]           │
└─────────────────────────────────────────┘
```

**Daily Challenge - Complete:**
```
┌─────────────────────────────────────────┐
│         📅 DAILY #127 COMPLETE          │
├─────────────────────────────────────────┤
│                                         │
│         ⬛🟩🟩⬛🟩                      │
│                                         │
│         Score: 3.5 / 7.5                │
│         (3 solved, 1 perfect)           │
│                                         │
│    ─────────────────────────────────    │
│    Come back tomorrow for Daily #128!   │
│                                         │
├─────────────────────────────────────────┤
│   [Share]    [Review]    [Main Menu]    │
└─────────────────────────────────────────┘

Share text (copied to clipboard):
Chess Puzzles Daily #127 🧩
⬛🟩🟩⬛🟩 3.5/7.5
Streak: 🔥2
```

#### 6. Stats Screen

**Overall Stats:**
- Total puzzles solved (all modes)
- Total time played
- Overall accuracy percentage

**Practice Stats:**
- Puzzles solved
- Current streak / Best streak
- Breakdown by mate depth (1, 2, 3, 4, 5, 6+)
- Rating distribution graph

**Sprint Stats:**
- Best scores by time limit (1 min / 3 min / 5 min)
- Average puzzles per run
- Total runs played

**Streak Stats:**
- Best streak (count)
- Highest rating reached
- Average streak length
- Total runs played

**Daily Challenge Stats:**
- Days played
- Current daily streak
- Best daily streak
- Average score
- Perfect days (7.5/7.5)

#### 7. Settings Menu

**Gameplay Settings:**
- **Show Legal Moves** — Highlight valid squares when piece selected (ON/OFF)
- **Auto-Flip Board** — Orient board from side-to-move perspective (ON/OFF)
- **Auto-Promote to Queen** — Skip promotion dialog in timed modes (ON/OFF, default ON)
- **Animation Speed** — Move animation duration (0.5x / 1x / 2x / Instant)

**Audio Settings:**
- **Sound Effects** — Enable/disable all sounds (ON/OFF)
- **Volume** — Master volume slider (0-100%)

**About:**
- **Licenses** → Opens Licenses Screen
- **Version** — Display current app version
- **Credits** — Link to acknowledgments

#### 8. Licenses Screen (GPL Compliance)

**Required for Stockfish distribution (GPLv3):**

```
┌─────────────────────────────────────────┐
│  ← Back              Licenses           │
├─────────────────────────────────────────┤
│                                         │
│  This application uses the following    │
│  open source software:                  │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  STOCKFISH                              │
│  Chess engine                           │
│  License: GPLv3                         │
│  https://stockfishchess.org             │
│                                         │
│  Source code available at:              │
│  https://github.com/official-stockfish  │
│                                         │
│  [View Full GPL License]                │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  LICHESS PUZZLE DATABASE                │
│  License: CC0 (Public Domain)           │
│  https://database.lichess.org           │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  GODOT ENGINE                           │
│  License: MIT                           │
│  https://godotengine.org                │
│                                         │
└─────────────────────────────────────────┘
```

**GPL Compliance Requirements:**
1. Include full GPL v3 license text (accessible via "View Full GPL License" button)
2. Provide link to Stockfish source code
3. Do NOT modify Stockfish without releasing your changes
4. This screen must be accessible from the main app (Settings → Licenses)

---

## Chess Logic Implementation Notes

### FEN Parsing

FEN has 6 fields separated by spaces:
1. Piece placement (ranks 8-1, separated by `/`)
2. Active color (`w` or `b`)
3. Castling availability (`KQkq` or `-`)
4. En passant target square or `-`
5. Halfmove clock
6. Fullmove number

Example: `rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1`

### Board Representation

Use a 64-element array (0-63):
- Index 0 = a8 (top-left from white's view)
- Index 7 = h8
- Index 56 = a1
- Index 63 = h1

Piece encoding (example):
```gdscript
const EMPTY = 0
const W_PAWN = 1, W_KNIGHT = 2, W_BISHOP = 3, W_ROOK = 4, W_QUEEN = 5, W_KING = 6
const B_PAWN = 9, B_KNIGHT = 10, B_BISHOP = 11, B_ROOK = 12, B_QUEEN = 13, B_KING = 14
# Bit 3 (value 8) indicates black
```

### Move Generation (Pseudocode)

For each piece type, generate candidate squares, then filter for:
1. Target square is empty or has enemy piece
2. Path is not blocked (for sliding pieces)
3. Move doesn't leave own king in check
4. Special rules: castling, en passant, pawn double-move

### UCI Move Format

- Standard: `e2e4` (from-square + to-square)
- Promotion: `e7e8q` (with piece letter: q/r/b/n)

---

## Test Plan

Automated tests are critical for chess logic correctness. The game should include comprehensive unit tests.

### Test Structure

```
tests/
├── test_fen_parser.gd
├── test_move_generation.gd
├── test_check_detection.gd
├── test_checkmate_detection.gd
├── test_special_moves.gd
├── test_puzzle_validation.gd
└── test_stockfish_integration.gd
```

### Test Categories

#### 1. FEN Parser (`test_fen_parser.gd`)

```gdscript
func test_starting_position():
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    chess_logic.parse_fen(fen)
    assert_eq(chess_logic.get_piece(0), B_ROOK)   # a8
    assert_eq(chess_logic.get_piece(4), B_KING)   # e8
    assert_eq(chess_logic.get_piece(63), W_ROOK)  # h1
    assert_eq(chess_logic.side_to_move, WHITE)
    assert_true(chess_logic.can_castle_kingside(WHITE))

func test_castling_rights_partial():
    var fen = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w Kq - 0 1"
    chess_logic.parse_fen(fen)
    assert_true(chess_logic.can_castle_kingside(WHITE))
    assert_false(chess_logic.can_castle_queenside(WHITE))
    assert_false(chess_logic.can_castle_kingside(BLACK))
    assert_true(chess_logic.can_castle_queenside(BLACK))

func test_en_passant_square():
    var fen = "rnbqkbnr/pppp1ppp/8/4pP2/8/8/PPPPP1PP/RNBQKBNR w KQkq e6 0 3"
    chess_logic.parse_fen(fen)
    assert_eq(chess_logic.en_passant_square, 20)  # e6

func test_invalid_fen_throws():
    assert_throws(func(): chess_logic.parse_fen("invalid"))
```

#### 2. Move Generation (`test_move_generation.gd`)

```gdscript
func test_pawn_single_push():
    # White pawn on e2
    var moves = chess_logic.get_legal_moves(52)  # e2
    assert_has(moves, 44)  # e3

func test_pawn_double_push():
    # Pawn on starting rank can move 2 squares
    var moves = chess_logic.get_legal_moves(52)  # e2
    assert_has(moves, 36)  # e4

func test_pawn_blocked():
    # Pawn blocked by piece in front
    var fen = "8/8/8/8/4p3/4P3/8/8 w - - 0 1"
    chess_logic.parse_fen(fen)
    var moves = chess_logic.get_legal_moves(44)  # e3
    assert_empty(moves)

func test_pawn_capture():
    var fen = "8/8/8/3p4/4P3/8/8/8 w - - 0 1"
    chess_logic.parse_fen(fen)
    var moves = chess_logic.get_legal_moves(36)  # e4
    assert_has(moves, 27)  # d5 capture

func test_knight_moves():
    # Knight on e4 should have up to 8 moves
    var fen = "8/8/8/8/4N3/8/8/8 w - - 0 1"
    chess_logic.parse_fen(fen)
    var moves = chess_logic.get_legal_moves(36)  # e4
    assert_has(moves, 19)  # d6
    assert_has(moves, 21)  # f6
    assert_has(moves, 30)  # g5
    # ... etc

func test_bishop_blocked():
    var fen = "8/8/8/8/4B3/3P4/8/8 w - - 0 1"
    chess_logic.parse_fen(fen)
    var moves = chess_logic.get_legal_moves(36)  # e4
    assert_not_has(moves, 54)  # Can't go through own pawn

func test_rook_sliding():
    var fen = "8/8/8/8/R7/8/8/8 w - - 0 1"
    chess_logic.parse_fen(fen)
    var moves = chess_logic.get_legal_moves(32)  # a4
    assert_eq(moves.size(), 14)  # 7 horizontal + 7 vertical
```

#### 3. Check Detection (`test_check_detection.gd`)

```gdscript
func test_simple_check():
    var fen = "4k3/8/8/8/8/8/8/4R2K w - - 0 1"
    chess_logic.parse_fen(fen)
    chess_logic.side_to_move = BLACK
    assert_true(chess_logic.is_in_check())

func test_double_check():
    var fen = "4k3/8/5N2/8/8/8/4R3/7K w - - 0 1"
    chess_logic.parse_fen(fen)
    chess_logic.side_to_move = BLACK
    assert_true(chess_logic.is_in_check())

func test_not_in_check():
    var fen = "4k3/8/8/8/8/8/8/R6K w - - 0 1"
    chess_logic.parse_fen(fen)
    chess_logic.side_to_move = BLACK
    assert_false(chess_logic.is_in_check())

func test_pinned_piece_check():
    # King on e8, rook on e1, bishop on e4 is pinned
    var fen = "4k3/8/8/8/4b3/8/8/4R2K w - - 0 1"
    chess_logic.parse_fen(fen)
    chess_logic.side_to_move = BLACK
    assert_true(chess_logic.is_in_check())  # Rook gives check through pinned bishop
```

#### 4. Checkmate Detection (`test_checkmate_detection.gd`)

```gdscript
func test_back_rank_mate():
    var fen = "6k1/5ppp/8/8/8/8/8/R6K w - - 0 1"
    chess_logic.parse_fen(fen)
    chess_logic.make_move(0, 7)  # Ra8#
    assert_true(chess_logic.is_checkmate())

func test_smothered_mate():
    var fen = "r5rk/6pp/7N/8/8/8/8/7K w - - 0 1"
    chess_logic.parse_fen(fen)
    assert_true(chess_logic.is_checkmate())

func test_not_checkmate_can_block():
    var fen = "4k3/8/8/8/8/8/4R3/R6K w - - 0 1"
    chess_logic.parse_fen(fen)
    chess_logic.side_to_move = BLACK
    assert_false(chess_logic.is_checkmate())  # Not even in check

func test_stalemate_not_checkmate():
    var fen = "k7/8/1K6/8/8/8/8/8 b - - 0 1"
    chess_logic.parse_fen(fen)
    # King has no moves but is not in check
    assert_false(chess_logic.is_checkmate())
    assert_true(chess_logic.is_stalemate())
```

#### 5. Special Moves (`test_special_moves.gd`)

```gdscript
func test_kingside_castle():
    var fen = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1"
    chess_logic.parse_fen(fen)
    assert_true(chess_logic.is_move_legal(60, 62))  # e1-g1
    chess_logic.make_move(60, 62)
    assert_eq(chess_logic.get_piece(62), W_KING)
    assert_eq(chess_logic.get_piece(61), W_ROOK)  # Rook moved too

func test_queenside_castle():
    var fen = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1"
    chess_logic.parse_fen(fen)
    assert_true(chess_logic.is_move_legal(60, 58))  # e1-c1
    chess_logic.make_move(60, 58)
    assert_eq(chess_logic.get_piece(58), W_KING)
    assert_eq(chess_logic.get_piece(59), W_ROOK)

func test_castle_through_check_illegal():
    var fen = "r3k2r/pppppppp/8/8/4r3/8/PPPP1PPP/R3K2R w KQkq - 0 1"
    chess_logic.parse_fen(fen)
    assert_false(chess_logic.is_move_legal(60, 62))  # Can't castle through e-file attack

func test_en_passant():
    var fen = "rnbqkbnr/pppp1ppp/8/4pP2/8/8/PPPPP1PP/RNBQKBNR w KQkq e6 0 3"
    chess_logic.parse_fen(fen)
    assert_true(chess_logic.is_move_legal(29, 20))  # f5xe6 e.p.
    chess_logic.make_move(29, 20)
    assert_eq(chess_logic.get_piece(20), W_PAWN)   # Pawn on e6
    assert_eq(chess_logic.get_piece(28), EMPTY)    # Captured pawn removed

func test_pawn_promotion():
    var fen = "8/P7/8/8/8/8/8/K6k w - - 0 1"
    chess_logic.parse_fen(fen)
    chess_logic.make_move(8, 0, QUEEN)  # a7-a8=Q
    assert_eq(chess_logic.get_piece(0), W_QUEEN)
```

#### 6. Puzzle Validation (`test_puzzle_validation.gd`)

```gdscript
func test_correct_move_accepted():
    # Scholar's mate position, Qxf7 is mate in 1
    var fen = "r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 4"
    puzzle_controller.load_puzzle(PuzzleData.new(fen, 1))
    var result = await puzzle_controller.validate_move(39, 13)  # Qh5xf7
    assert_true(result)

func test_alternate_mate_accepted():
    # Position with multiple mate-in-1 moves
    var fen = "6k1/5ppp/8/8/8/8/1Q6/R6K w - - 0 1"
    puzzle_controller.load_puzzle(PuzzleData.new(fen, 1))
    # Both Ra8# and Qb8# should be accepted
    assert_true(await puzzle_controller.validate_move(56, 0))   # Ra8#
    
    puzzle_controller.load_puzzle(PuzzleData.new(fen, 1))  # Reset
    assert_true(await puzzle_controller.validate_move(49, 1))   # Qb8#

func test_non_mating_move_rejected():
    var fen = "6k1/5ppp/8/8/8/8/1Q6/R6K w - - 0 1"
    puzzle_controller.load_puzzle(PuzzleData.new(fen, 1))
    var result = await puzzle_controller.validate_move(56, 48)  # Ra2 (not mate)
    assert_false(result)

func test_slower_mate_rejected():
    # Mate in 1 required, but move leads to mate in 2
    # (Hypothetical - would need specific position)
    pass
```

#### 7. Stockfish Integration (`test_stockfish_integration.gd`)

```gdscript
func test_engine_starts():
    var bridge = StockfishBridge.new()
    await bridge.ready
    assert_true(bridge.is_running())

func test_mate_detection():
    var bridge = StockfishBridge.new()
    var fen = "6k1/5ppp/8/8/8/8/8/R6K w - - 0 1"
    var result = await bridge.analyze_position(fen)
    assert_eq(result.mate_in, 1)

func test_best_move_parsing():
    var bridge = StockfishBridge.new()
    var fen = "6k1/5ppp/8/8/8/8/8/R6K w - - 0 1"
    var best = await bridge.get_best_move(fen)
    assert_eq(best, "a1a8")  # Ra8#

func test_no_mate_returns_null():
    var bridge = StockfishBridge.new()
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    var result = await bridge.analyze_position(fen)
    assert_null(result.mate_in)
```

### Running Tests

```bash
# Using GUT (Godot Unit Test) framework
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Project setup, folder structure
- [ ] Download and preprocess Lichess puzzle database
- [ ] Implement mate depth validation in preprocessing
- [ ] Implement FEN parser
- [ ] Basic board rendering (static position)
- [ ] Piece sprites integration

### Phase 2: Chess Logic (Week 2)
- [ ] Move generation for all piece types
- [ ] Check and checkmate detection
- [ ] Move validation
- [ ] Special moves (castling, en passant, promotion)
- [ ] Unit tests for chess logic (GUT framework)

### Phase 3: Stockfish Integration (Week 3)
- [ ] Stockfish bridge (UCI protocol over stdin/stdout)
- [ ] Position analysis (mate detection)
- [ ] Best move retrieval
- [ ] Platform-specific binary bundling
- [ ] Integration tests

### Phase 4: Interaction (Week 4)
- [ ] Square selection and highlighting
- [ ] Move input (click-click and drag-drop)
- [ ] Legal move display
- [ ] Move animation
- [ ] Promotion dialog

### Phase 5: Practice Mode & Core Puzzle System (Week 5)
- [ ] SQLite integration (puzzles + user history)
- [ ] Puzzle loading and filtering
- [ ] Puzzle controller state machine
- [ ] Stockfish-based move validation
- [ ] Stockfish-based opponent response
- [ ] Hint and solution reveal
- [ ] Practice mode complete

### Phase 6: Game Modes (Week 6)
- [ ] Sprint mode (timer, strikes, scoring)
- [ ] Streak mode (difficulty progression, game over)
- [ ] Daily challenge (deterministic seeding, share text)
- [ ] Mode-specific HUD components
- [ ] Game over screens for each mode
- [ ] Replay last puzzle feature

### Phase 7: UI & Stats (Week 7)
- [ ] Main menu with mode selection
- [ ] Mode setup screens
- [ ] Stats tracking per mode (SQLite)
- [ ] Stats display screen
- [ ] Settings menu

### Phase 8: Polish & Launch (Week 8)
- [ ] Sound effects
- [ ] Animations and transitions
- [ ] Playtesting and bug fixes
- [ ] Performance optimization
- [ ] Full test suite passing
- [ ] Export builds (Windows, macOS, Linux)
- [ ] README and distribution

---

## Dependencies & Assets

### Godot Plugins
- **godot-sqlite** — SQLite database access (https://github.com/2shady4u/godot-sqlite)
- **GUT (Godot Unit Test)** — Unit testing framework (https://github.com/bitwes/Gut)

### External Binaries
- **Stockfish** — Chess engine for move validation (https://stockfishchess.org/download/)
  - Required builds: Windows (x64), macOS (x64 + ARM), Linux (x64)
  - ~10-30MB per platform
  - MIT License

### Preprocessing Tools (Python)
- **python-chess** — FEN parsing, move validation during preprocessing
- **Stockfish** — For mate depth validation (optional, for extra accuracy)

```
# tools/requirements.txt
python-chess>=1.9.0
```

### Assets Needed
- Chess piece sprites (12 images) — Use freely licensed sets from:
  - Lichess (https://github.com/lichess-org/lila) — MIT license
  - Wikimedia Commons chess pieces
  - Colin M.L. Burnett set (BSD license)
- UI icons (hint, skip, settings, timer, strike, etc.)
- Sound effects (move, capture, check, success, failure, tick)

### Data Preprocessing

Python script workflow:

```bash
# 1. Download Lichess puzzle CSV
wget https://database.lichess.org/lichess_db_puzzle.csv.zst
zstd -d lichess_db_puzzle.csv.zst

# 2. Run preprocessing
cd tools/
python preprocess_puzzles.py \
    --input ../lichess_db_puzzle.csv \
    --output ../data/puzzles.db \
    --max-mate-depth 5 \
    --validate-depths
```

Preprocessing script responsibilities:
1. Filter for `mateIn1` through `mateIn5` themes
2. Validate move count matches mate depth
3. Extract relevant columns (id, fen, moves, rating, mate_in)
4. Export to SQLite database
5. Log and discard invalid puzzles

---

## Success Metrics

**Technical:**
- Player can solve 100 puzzles without crashes
- Chess logic correctly validates all legal moves
- Average puzzle load time < 100ms
- Smooth 60fps during gameplay
- Database query time < 50ms
- Engine analysis completes in <200ms for mate-in-3 (typical hardware)

**Engine Integration:**
- Stockfish spawns successfully on all desktop platforms
- UCI communication is reliable (no dropped commands)
- Threading prevents UI freezing during analysis
- "Thinking" indicator appears only when analysis exceeds 150ms

**Mode-Specific:**
- Sprint mode timer is accurate to ±100ms
- Daily challenge generates identical puzzles for same date across all installs (hash-based)
- Streak mode correctly increments difficulty by 25-50 rating per puzzle
- Share text copies correctly to clipboard
- Auto-promotion correctly identifies winning under-promotions

**User Experience:**
- All four modes playable end-to-end
- Stats persist correctly across sessions
- Mode transitions feel snappy (< 500ms)
- Licenses screen accessible and displays GPL compliance info

**Platform:**
- Windows, macOS, Linux exports work correctly
- macOS build passes Gatekeeper (signed binaries)

---

## Open Questions

1. ~~**Offline-first or allow network features?**~~ — Start offline-only ✓
2. ~~**Support mobile from the start?**~~ — Desktop MVP only; mobile requires GDExtension (future) ✓
3. **Multiple hint levels?** — V1: single hint (highlight correct piece); V2: progressive hints
4. **Undo move?** — Yes, allow undo on incorrect moves before showing solution (Practice mode only)
5. **Database updates?** — How to handle puzzle DB updates without breaking Daily Challenge determinism?

---

## References

- Lichess Puzzle Database: https://database.lichess.org/#puzzles
- Lichess Source (for piece assets): https://github.com/lichess-org/lila
- Godot SQLite Plugin: https://github.com/2shady4u/godot-sqlite
- GUT (Godot Unit Test): https://github.com/bitwes/Gut
- Stockfish Chess Engine: https://stockfishchess.org/
- Stockfish Source (GPL): https://github.com/official-stockfish/Stockfish
- FEN Specification: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
- UCI Protocol: https://en.wikipedia.org/wiki/Universal_Chess_Interface
