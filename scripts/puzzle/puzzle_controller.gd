class_name PuzzleController
extends Node
## Controls puzzle gameplay flow across all game modes.
## Manages state machine, move validation, and opponent responses.

## Game mode enumeration
enum GameMode { PRACTICE, SPRINT, STREAK, DAILY }

## Puzzle state enumeration
enum PuzzleState {
	LOADING,           # Loading puzzle data
	PLAYER_TURN,       # Waiting for player move
	OPPONENT_TURN,     # Playing opponent response
	COMPLETED_SUCCESS, # Puzzle solved correctly
	COMPLETED_FAILED,  # Puzzle failed
	SHOWING_SOLUTION,  # Displaying solution moves
	GAME_OVER          # Game session ended
}

## Emitted when puzzle state changes
signal state_changed(old_state: PuzzleState, new_state: PuzzleState)

## Emitted when a puzzle is loaded and ready
signal puzzle_loaded(puzzle: PuzzleData)

## Emitted when a move is made (by player or opponent)
signal move_made(from: int, to: int, is_correct: bool)

## Emitted when puzzle is completed
signal puzzle_completed(success: bool, attempts: int)

## Emitted when opponent is about to move (for UI animation)
signal opponent_moving(from: int, to: int)

## Emitted when game session ends
signal game_over(mode: GameMode, stats: Dictionary)

## Emitted when a hint is requested
signal hint_requested(move_uci: String)

## Emitted when engine analysis begins (for thinking indicator)
signal analysis_started()

## Emitted when engine analysis completes
signal analysis_completed()

## Emitted when a puzzle fails validation (skip to next)
signal puzzle_invalid(puzzle_id: String, reason: String)

## Emitted when an incorrect move is made (for UI modal)
signal incorrect_move(can_retry: bool, can_skip: bool)

## Emitted when puzzle is solved (for UI modal)
signal puzzle_solved()

# Saved state for reverting incorrect moves
var _incorrect_move_state: Dictionary = {}

# Current game state
var current_mode: GameMode = GameMode.PRACTICE
var current_puzzle: PuzzleData = null
var current_state: PuzzleState = PuzzleState.LOADING
var move_index: int = 0
var attempt_count: int = 0

# Mode-specific tracking
var streak_count: int = 0
var strikes: int = 0
const MAX_STRIKES: int = 3

# Validator for move checking
var puzzle_validator: PuzzleValidator

# Animation delay for opponent moves
@export var opponent_move_delay: float = 0.3

# Guard flag to prevent re-entrant calls to _play_opponent_move
var _opponent_move_in_progress: bool = false

# Move history for undo/redo
var _move_history: Array[Dictionary] = []  # List of {state, move_index, from, to}
var _history_position: int = -1  # Current position in history (-1 = at start)

## Emitted when history changes (for UI button states)
signal history_changed(can_undo: bool, can_redo: bool)


func _ready() -> void:
	puzzle_validator = PuzzleValidator.new()


## Load a puzzle and set up the position.
## Returns true if puzzle loaded successfully, false if validation failed.
func load_puzzle(puzzle: PuzzleData) -> bool:
	print("[PuzzleController] ========== LOADING PUZZLE ==========")
	print("[PuzzleController] Call stack: %s" % [get_stack()])
	print("[PuzzleController] Puzzle ID: %s, FEN: %s" % [puzzle.id if puzzle else "NULL", puzzle.fen if puzzle else "NULL"])
	print("[PuzzleController] ChessLogic state BEFORE parse_fen: side_to_move=%d, FEN=%s" % [
		ChessLogic.side_to_move, ChessLogic.to_fen()])
	_set_state(PuzzleState.LOADING)

	# Runtime validation - verify puzzle solution delivers checkmate
	var validation = puzzle_validator.validate_puzzle(puzzle)
	if not validation["valid"]:
		push_warning("[PuzzleController] INVALID PUZZLE %s: %s" % [puzzle.id, validation["reason"]])
		puzzle_invalid.emit(puzzle.id, validation["reason"])
		return false

	current_puzzle = puzzle
	move_index = 0
	attempt_count = 0
	strikes = 0
	_opponent_move_in_progress = false  # Reset re-entry guard

	# Clear move history
	_move_history.clear()
	_history_position = -1
	history_changed.emit(false, false)

	# Set initial position from FEN
	ChessLogic.parse_fen(puzzle.fen)
	print("[PuzzleController] ChessLogic state AFTER parse_fen: side_to_move=%d, FEN=%s" % [
		ChessLogic.side_to_move, ChessLogic.to_fen()])

	# Emit signal for UI to update
	print("[PuzzleController] Emitting puzzle_loaded signal")
	puzzle_loaded.emit(puzzle)

	# Check if first move is opponent (setup move)
	# In Lichess puzzles, the first move is always the opponent's move that sets up the puzzle
	if _is_opponent_first_move():
		_set_state(PuzzleState.OPPONENT_TURN)
		await _play_opponent_move()
	else:
		_set_state(PuzzleState.PLAYER_TURN)

	return true


## Check if the first move should be played by opponent.
func _is_opponent_first_move() -> bool:
	# Lichess puzzles format:
	# - FEN shows position BEFORE opponent's blunder
	# - First move in solution is opponent's blunder/setup move
	# - Player then finds the winning response
	#
	# For mate-in-N puzzles:
	# - Mate in 1: solution has 2 moves (opponent blunder, player checkmate)
	# - Mate in 2: solution has 4 moves (opponent, player, opponent, player checkmate)
	# - etc. Formula: 2 * mate_in moves
	#
	# BUT the preprocessing script says:
	# - Mate in 1: 1 move (just player's checkmate)
	# - Mate in 2: 3 moves (player, opponent, player checkmate)
	# - Formula: 2 * mate_in - 1 moves
	#
	# This means: if moves == 2*N-1, player moves first; if moves == 2*N, opponent moves first

	if current_puzzle.solution_moves.is_empty():
		return false

	var move_count = current_puzzle.solution_moves.size()
	var expected_player_first = 2 * current_puzzle.mate_in - 1

	# If move count matches expected player-first pattern, player goes first
	if move_count == expected_player_first:
		print("[PuzzleController] Player moves first (move_count=%d, expected=%d)" % [move_count, expected_player_first])
		return false
	else:
		# Otherwise opponent goes first (has setup move)
		print("[PuzzleController] Opponent moves first (move_count=%d, expected=%d)" % [move_count, expected_player_first])
		return true


## Submit a player move for validation.
func submit_move(from: int, to: int, promotion: int = ChessLogic.EMPTY) -> void:
	if current_state != PuzzleState.PLAYER_TURN:
		return

	var move_uci = ChessLogic.squares_to_uci(from, to, promotion)
	var current_fen = ChessLogic.to_fen()

	# Calculate remaining mate depth
	var remaining_mate = _calculate_remaining_mate()

	# First check if this matches the expected solution move
	var expected_move = current_puzzle.get_current_move(move_index)
	var is_expected = (move_uci == expected_move)

	# Validate the move
	var validation_result: Dictionary

	if is_expected:
		# Move matches solution - accept it
		validation_result = {
			"valid": true,
			"is_checkmate": current_puzzle.is_final_move(move_index),
			"new_mate_in": remaining_mate - 1,
			"reason": ""
		}
	else:
		# Move doesn't match - check if it's an alternate winning line
		analysis_started.emit()
		validation_result = await puzzle_validator.validate_move(current_fen, move_uci, remaining_mate)
		analysis_completed.emit()

	if validation_result["valid"]:
		_handle_correct_move(from, to, promotion, validation_result["is_checkmate"])
	else:
		_handle_incorrect_move(from, to, validation_result["reason"])


## Handle a correct move.
func _handle_correct_move(from: int, to: int, promotion: int, is_checkmate: bool) -> void:
	# Save state before making the move (for undo)
	_save_to_history(from, to)

	# Make the move on the board
	ChessLogic.make_move(from, to, promotion)
	move_index += 1
	move_made.emit(from, to, true)

	if is_checkmate or ChessLogic.is_checkmate():
		_handle_puzzle_success()
	else:
		_set_state(PuzzleState.OPPONENT_TURN)
		await _play_opponent_move()


## Handle an incorrect move.
func _handle_incorrect_move(from: int, to: int, _reason: String) -> void:
	attempt_count += 1

	# Save board state before making the move so we can revert later
	_incorrect_move_state = ChessLogic.copy_board_state()

	# Make the move visually so player sees it happen
	ChessLogic.make_move(from, to)
	move_made.emit(from, to, false)

	# Set state to prevent further moves while modal is shown
	_set_state(PuzzleState.COMPLETED_FAILED)

	# Determine what options to show based on mode
	var can_retry = true
	var can_skip = true

	match current_mode:
		GameMode.PRACTICE:
			# Unlimited retries, can skip
			can_retry = true
			can_skip = true

		GameMode.SPRINT:
			# Time penalty handled elsewhere, can retry but no skip
			can_retry = true
			can_skip = false

		GameMode.STREAK:
			# One mistake ends streak - no retry, must go to next
			can_retry = false
			can_skip = true  # "Next" means game over

		GameMode.DAILY:
			strikes += 1
			if strikes >= MAX_STRIKES:
				# Three strikes - puzzle failed, must move on
				can_retry = false
				can_skip = true
			else:
				# Can still retry
				can_retry = true
				can_skip = false

	# Emit signal for UI to show modal
	incorrect_move.emit(can_retry, can_skip)


## Play the opponent's response move.
func _play_opponent_move() -> void:
	print("[PuzzleController] _play_opponent_move CALLED: state=%d, in_progress=%s, move_index=%d" % [
		current_state, _opponent_move_in_progress, move_index])

	if current_state != PuzzleState.OPPONENT_TURN:
		print("[PuzzleController] _play_opponent_move skipped: state is %d, not OPPONENT_TURN" % current_state)
		return

	# Guard against re-entrant calls (can happen with async/await)
	if _opponent_move_in_progress:
		print("[PuzzleController] _play_opponent_move skipped: already in progress")
		return
	_opponent_move_in_progress = true
	print("[PuzzleController] _play_opponent_move PROCEEDING with move_index=%d" % move_index)

	var opponent_move: String

	# Get the next move from solution
	if move_index < current_puzzle.solution_moves.size():
		opponent_move = current_puzzle.solution_moves[move_index]
	else:
		# Beyond solution - get Stockfish best move
		var fen = ChessLogic.to_fen()
		analysis_started.emit()
		opponent_move = await puzzle_validator.get_best_move(fen)
		analysis_completed.emit()

	if opponent_move.is_empty():
		push_error("No opponent move available")
		return

	# Parse the move
	var move_data = ChessLogic.uci_to_squares(opponent_move)
	if move_data["from"] < 0:
		push_error("Invalid opponent move: %s" % opponent_move)
		return

	# Emit signal for UI to animate
	opponent_moving.emit(move_data["from"], move_data["to"])

	# Wait for animation
	await get_tree().create_timer(opponent_move_delay).timeout

	# Save state before opponent move (for undo)
	_save_to_history(move_data["from"], move_data["to"])

	# Make the move
	var from_sq = move_data["from"]
	var to_sq = move_data["to"]
	var piece_at_from = ChessLogic.get_piece(from_sq)
	var piece_at_to = ChessLogic.get_piece(to_sq)
	var piece_color = ChessLogic.get_piece_color(piece_at_from)
	print("[PuzzleController] About to make opponent move: from=%d, to=%d, current FEN=%s, side_to_move=%d" % [
		from_sq, to_sq, ChessLogic.to_fen(), ChessLogic.side_to_move])
	print("[PuzzleController] Piece at from(%d): %d, color: %d | Piece at to(%d): %d | Expected puzzle FEN: %s" % [
		from_sq, piece_at_from, piece_color, to_sq, piece_at_to, current_puzzle.fen])

	# Check if piece color matches side_to_move before attempting
	if piece_at_from == ChessLogic.EMPTY:
		push_error("[PuzzleController] NO PIECE at from square %d! Board may be in wrong state." % from_sq)
	elif piece_color != ChessLogic.side_to_move:
		push_error("[PuzzleController] Piece color (%d) != side_to_move (%d)! Likely stale board state." % [
			piece_color, ChessLogic.side_to_move])
		# Re-parse the FEN to fix the state
		print("[PuzzleController] Re-parsing FEN to fix state: %s" % current_puzzle.fen)
		ChessLogic.parse_fen(current_puzzle.fen)
		print("[PuzzleController] After re-parse: FEN=%s, side_to_move=%d" % [
			ChessLogic.to_fen(), ChessLogic.side_to_move])

	var move_success = ChessLogic.make_move(from_sq, to_sq, move_data["promotion"])
	print("[PuzzleController] make_move returned: %s, new FEN=%s, side_to_move=%d" % [
		move_success, ChessLogic.to_fen(), ChessLogic.side_to_move])
	if not move_success:
		push_error("[PuzzleController] Opponent move failed! move=%s, from=%d, to=%d" % [
			current_puzzle.solution_moves[move_index] if move_index < current_puzzle.solution_moves.size() else "?",
			from_sq, to_sq])
		# Check legal moves for the piece
		var legal = ChessLogic.get_legal_moves(from_sq)
		print("[PuzzleController] Legal moves for square %d: %s" % [from_sq, legal])
		# Force the side to move to swap anyway so player can continue
		if ChessLogic.side_to_move == ChessLogic.PieceColor.WHITE:
			ChessLogic.side_to_move = ChessLogic.PieceColor.BLACK
		else:
			ChessLogic.side_to_move = ChessLogic.PieceColor.WHITE
		print("[PuzzleController] Forced side_to_move to %d" % ChessLogic.side_to_move)
	move_index += 1

	# Check if opponent delivered checkmate (puzzle failed)
	print("[PuzzleController] Before is_checkmate check: side_to_move=%d" % ChessLogic.side_to_move)
	var is_mate = ChessLogic.is_checkmate()
	print("[PuzzleController] After is_checkmate check: side_to_move=%d, is_mate=%s" % [ChessLogic.side_to_move, is_mate])

	# Clear the re-entry guard before changing state
	_opponent_move_in_progress = false

	if is_mate:
		_handle_puzzle_failed("Opponent delivered checkmate")
	else:
		print("[PuzzleController] Setting state to PLAYER_TURN, side_to_move=%d" % ChessLogic.side_to_move)
		_set_state(PuzzleState.PLAYER_TURN)


## Calculate the remaining mate depth.
func _calculate_remaining_mate() -> int:
	# Calculate based on current move index and puzzle mate depth
	var moves_made = move_index
	var player_moves_made = (moves_made + 1) / 2
	return max(1, current_puzzle.mate_in - player_moves_made)


## Revert an incorrect move (called when user chooses "Try Again").
func revert_incorrect_move() -> void:
	if _incorrect_move_state.is_empty():
		return

	ChessLogic.restore_board_state(_incorrect_move_state)
	_incorrect_move_state.clear()
	_set_state(PuzzleState.PLAYER_TURN)
	move_made.emit(-1, -1, true)  # Signal board refresh


## Handle successful puzzle completion.
func _handle_puzzle_success() -> void:
	_set_state(PuzzleState.COMPLETED_SUCCESS)
	streak_count += 1
	puzzle_solved.emit()
	puzzle_completed.emit(true, attempt_count)


## Handle puzzle failure.
func _handle_puzzle_failed(reason: String) -> void:
	_set_state(PuzzleState.COMPLETED_FAILED)
	puzzle_completed.emit(false, attempt_count)


## Reset the current puzzle for retry.
func reset_puzzle() -> bool:
	if current_puzzle:
		return await load_puzzle(current_puzzle)
	return false


## Show the solution (remaining moves).
func show_solution() -> void:
	_set_state(PuzzleState.SHOWING_SOLUTION)

	# Emit each remaining move for UI to animate
	while move_index < current_puzzle.solution_moves.size():
		var move_uci = current_puzzle.solution_moves[move_index]
		hint_requested.emit(move_uci)

		var move_data = ChessLogic.uci_to_squares(move_uci)
		if move_data["from"] >= 0:
			opponent_moving.emit(move_data["from"], move_data["to"])
			await get_tree().create_timer(opponent_move_delay).timeout
			ChessLogic.make_move(move_data["from"], move_data["to"], move_data["promotion"])

		move_index += 1


## Request a hint (shows next move).
func get_hint() -> String:
	if move_index < current_puzzle.solution_moves.size():
		var hint = current_puzzle.solution_moves[move_index]
		hint_requested.emit(hint)
		return hint
	return ""


## Trigger game over with current stats.
func trigger_game_over() -> void:
	_set_state(PuzzleState.GAME_OVER)
	var stats = {
		"streak": streak_count,
		"strikes": strikes,
		"mode": current_mode,
		"puzzles_completed": streak_count
	}
	game_over.emit(current_mode, stats)


## Set the game mode.
func set_mode(mode: GameMode) -> void:
	current_mode = mode
	streak_count = 0
	strikes = 0


## Update state with transition validation.
func _set_state(new_state: PuzzleState) -> void:
	if new_state == current_state:
		return

	var old_state = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


## Check if a move can be made.
func can_make_move() -> bool:
	return current_state == PuzzleState.PLAYER_TURN


## Get current state.
func get_state() -> PuzzleState:
	return current_state


## Get current puzzle info.
func get_puzzle_info() -> Dictionary:
	if not current_puzzle:
		return {}
	return {
		"id": current_puzzle.id,
		"rating": current_puzzle.rating,
		"mate_in": current_puzzle.mate_in,
		"move_index": move_index,
		"total_moves": current_puzzle.solution_moves.size(),
		"attempts": attempt_count,
		"strikes": strikes
	}


# =============================================================================
# UNDO/REDO FUNCTIONALITY
# =============================================================================

## Save current state to history before a move.
func _save_to_history(from: int, to: int) -> void:
	# If we're not at the end of history, truncate future moves
	if _history_position < _move_history.size() - 1:
		_move_history.resize(_history_position + 1)

	# Save the current state BEFORE the move
	var entry = {
		"board_state": ChessLogic.copy_board_state(),
		"move_index": move_index,
		"from": from,
		"to": to
	}
	_move_history.append(entry)
	_history_position = _move_history.size() - 1

	history_changed.emit(can_undo(), can_redo())


## Check if undo is available.
func can_undo() -> bool:
	return _history_position >= 0


## Check if redo is available.
func can_redo() -> bool:
	return _history_position < _move_history.size() - 1


## Undo the last move (goes back one step).
func undo_move() -> void:
	if not can_undo():
		return

	# Get the entry at current position (state BEFORE that move was made)
	var entry = _move_history[_history_position]

	# Restore the board state
	ChessLogic.restore_board_state(entry["board_state"])
	move_index = entry["move_index"]

	# Move back in history
	_history_position -= 1

	# Update game state
	_set_state(PuzzleState.PLAYER_TURN)

	# Emit signals
	move_made.emit(entry["to"], entry["from"], true)  # Reversed for visual
	history_changed.emit(can_undo(), can_redo())


## Redo the last undone move (goes forward one step).
func redo_move() -> void:
	if not can_redo():
		return

	# Move forward in history
	_history_position += 1

	# Get the entry we're redoing
	var entry = _move_history[_history_position]

	# We need to get the state AFTER this move was made
	# The entry stores state BEFORE, so we replay the move
	ChessLogic.restore_board_state(entry["board_state"])
	ChessLogic.make_move(entry["from"], entry["to"])
	move_index = entry["move_index"] + 1

	# Check if this was an opponent move (odd index in solution = opponent response)
	# If we're at opponent's turn after redo, play their move too
	if _history_position < _move_history.size() - 1:
		var next_entry = _move_history[_history_position + 1]
		# Check if next move is opponent's by seeing if move_index is odd
		if next_entry["move_index"] % 2 == 1:  # Opponent move
			_history_position += 1
			ChessLogic.make_move(next_entry["from"], next_entry["to"])
			move_index = next_entry["move_index"] + 1

	# Update game state
	_set_state(PuzzleState.PLAYER_TURN)

	# Emit signals
	move_made.emit(entry["from"], entry["to"], true)
	history_changed.emit(can_undo(), can_redo())


## Go back to the start of the puzzle.
func go_to_start() -> void:
	if not current_puzzle:
		return

	# Restore initial position
	ChessLogic.parse_fen(current_puzzle.fen)
	move_index = 0
	_history_position = -1

	# If opponent moves first, replay their move
	if _is_opponent_first_move() and _move_history.size() > 0:
		var first_entry = _move_history[0]
		ChessLogic.make_move(first_entry["from"], first_entry["to"])
		move_index = 1
		_history_position = 0

	_set_state(PuzzleState.PLAYER_TURN)
	move_made.emit(-1, -1, true)  # Signal refresh
	history_changed.emit(can_undo(), can_redo())


## Go to the end of the current moves (latest position).
func go_to_end() -> void:
	while can_redo():
		redo_move()
