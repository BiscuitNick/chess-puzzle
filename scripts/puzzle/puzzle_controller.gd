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


func _ready() -> void:
	puzzle_validator = PuzzleValidator.new()


## Load a puzzle and set up the position.
func load_puzzle(puzzle: PuzzleData) -> void:
	_set_state(PuzzleState.LOADING)

	current_puzzle = puzzle
	move_index = 0
	attempt_count = 0
	strikes = 0

	# Set initial position from FEN
	ChessLogic.parse_fen(puzzle.fen)

	# Emit signal for UI to update
	puzzle_loaded.emit(puzzle)

	# Check if first move is opponent (setup move)
	# In Lichess puzzles, the first move is always the opponent's move that sets up the puzzle
	if _is_opponent_first_move():
		_set_state(PuzzleState.OPPONENT_TURN)
		await _play_opponent_move()
	else:
		_set_state(PuzzleState.PLAYER_TURN)


## Check if the first move should be played by opponent.
func _is_opponent_first_move() -> bool:
	# Lichess puzzles typically start with opponent move
	# Check if we have moves and the position requires opponent to move first
	if current_puzzle.solution_moves.is_empty():
		return false

	# The puzzle FEN shows the position before the first move
	# If it's the opponent's turn in the FEN, they move first
	# For puzzles, "opponent" is the side that sets up the tactic

	# Simple heuristic: if total moves is odd and mate_in matches,
	# first move is opponent (setup)
	# For mate-in-N, solution should have 2*N - 1 moves if player delivers mate
	# Or 2*N moves if there's an additional setup move

	return current_puzzle.solution_moves.size() > 0


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
		validation_result = await puzzle_validator.validate_move(current_fen, move_uci, remaining_mate)

	if validation_result["valid"]:
		_handle_correct_move(from, to, promotion, validation_result["is_checkmate"])
	else:
		_handle_incorrect_move(from, to, validation_result["reason"])


## Handle a correct move.
func _handle_correct_move(from: int, to: int, promotion: int, is_checkmate: bool) -> void:
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
func _handle_incorrect_move(from: int, to: int, reason: String) -> void:
	attempt_count += 1
	move_made.emit(from, to, false)

	match current_mode:
		GameMode.PRACTICE:
			# Unlimited retries in practice mode
			pass

		GameMode.SPRINT:
			# Time penalty handled elsewhere, allow retry
			pass

		GameMode.STREAK:
			# One mistake ends streak
			_set_state(PuzzleState.COMPLETED_FAILED)
			_handle_puzzle_failed(reason)

		GameMode.DAILY:
			strikes += 1
			if strikes >= MAX_STRIKES:
				_set_state(PuzzleState.COMPLETED_FAILED)
				_handle_puzzle_failed("Three strikes - puzzle failed")


## Play the opponent's response move.
func _play_opponent_move() -> void:
	if current_state != PuzzleState.OPPONENT_TURN:
		return

	var opponent_move: String

	# Get the next move from solution
	if move_index < current_puzzle.solution_moves.size():
		opponent_move = current_puzzle.solution_moves[move_index]
	else:
		# Beyond solution - get Stockfish best move
		var fen = ChessLogic.to_fen()
		opponent_move = await puzzle_validator.get_best_move(fen)

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

	# Make the move
	ChessLogic.make_move(move_data["from"], move_data["to"], move_data["promotion"])
	move_index += 1

	# Check if opponent delivered checkmate (puzzle failed)
	if ChessLogic.is_checkmate():
		_handle_puzzle_failed("Opponent delivered checkmate")
	else:
		_set_state(PuzzleState.PLAYER_TURN)


## Calculate the remaining mate depth.
func _calculate_remaining_mate() -> int:
	# Calculate based on current move index and puzzle mate depth
	var moves_made = move_index
	var player_moves_made = (moves_made + 1) / 2
	return max(1, current_puzzle.mate_in - player_moves_made)


## Handle successful puzzle completion.
func _handle_puzzle_success() -> void:
	_set_state(PuzzleState.COMPLETED_SUCCESS)
	streak_count += 1
	puzzle_completed.emit(true, attempt_count)


## Handle puzzle failure.
func _handle_puzzle_failed(reason: String) -> void:
	_set_state(PuzzleState.COMPLETED_FAILED)
	puzzle_completed.emit(false, attempt_count)


## Reset the current puzzle for retry.
func reset_puzzle() -> void:
	if current_puzzle:
		await load_puzzle(current_puzzle)


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
