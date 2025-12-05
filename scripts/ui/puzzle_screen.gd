class_name PuzzleScreen
extends Control
## Main puzzle gameplay screen with mode-aware HUD.

# BUILD NUMBER - increment this to verify you're running latest code
const BUILD: int = 13

signal main_menu_requested()
signal back_requested()

# Mode references
var practice_mode: PracticeMode
var sprint_mode: SprintMode
var streak_mode: StreakMode
var daily_mode: DailyMode
var puzzle_controller: PuzzleController

# Current mode
var current_mode: PuzzleController.GameMode = PuzzleController.GameMode.PRACTICE
var mode_settings: Dictionary = {}

# UI References - new layout paths
@onready var chess_board: ChessBoard = $MainLayout/ContentArea/LeftPanel/BoardWrapper/ChessBoard
@onready var back_btn: Button = $MainLayout/TopBar/HBoxContainer/BackButton
@onready var puzzle_info_label: Label = $MainLayout/TopBar/HBoxContainer/PuzzleInfo

# Button bar references
@onready var button_bar: HBoxContainer = $MainLayout/ContentArea/LeftPanel/ButtonBar
@onready var undo_btn: Button = $MainLayout/ContentArea/LeftPanel/ButtonBar/UndoButton
@onready var redo_btn: Button = $MainLayout/ContentArea/LeftPanel/ButtonBar/RedoButton
@onready var hint_btn: Button = $MainLayout/ContentArea/LeftPanel/ButtonBar/HintButton
@onready var solution_btn: Button = $MainLayout/ContentArea/LeftPanel/ButtonBar/SolutionButton
@onready var skip_btn: Button = $MainLayout/ContentArea/LeftPanel/ButtonBar/SkipButton
@onready var next_btn: Button = $MainLayout/ContentArea/LeftPanel/ButtonBar/NextButton

# Right panel - tabs
@onready var right_panel: TabContainer = $MainLayout/ContentArea/RightPanel
@onready var options_tab: VBoxContainer = $MainLayout/ContentArea/RightPanel/Options
@onready var flip_board_btn: Button = $MainLayout/ContentArea/RightPanel/Options/FlipBoardButton

# Debug panel references (in Debug tab)
@onready var debug_build_time: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/BuildTime
@onready var debug_db_version: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/DBVersion
@onready var debug_puzzle_id: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/PuzzleID
@onready var debug_puzzle_number: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/PuzzleNumber
@onready var debug_fen: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/FEN
@onready var debug_move_index: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/MoveIndex
@onready var debug_expected_move: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/ExpectedMove
@onready var debug_current_fen: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/CurrentFEN
@onready var debug_moves_list: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/MovesList
@onready var debug_solution_list: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/SolutionList
@onready var debug_puzzle_state: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/PuzzleState
@onready var debug_attempts: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/Attempts
@onready var debug_rating: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/Rating
@onready var debug_mate_in: Label = $MainLayout/ContentArea/RightPanel/Debug/VBox/MateIn

# Mode HUD elements
@onready var mode_hud: HBoxContainer = $MainLayout/ContentArea/LeftPanel/ModeHUD

# Sprint HUD elements
@onready var sprint_hud: Control = $MainLayout/ContentArea/LeftPanel/ModeHUD/SprintHUD
@onready var timer_display: TimerDisplay = $MainLayout/ContentArea/LeftPanel/ModeHUD/SprintHUD/TimerDisplay
@onready var strike_indicator: StrikeIndicator = $MainLayout/ContentArea/LeftPanel/ModeHUD/SprintHUD/StrikeIndicator
@onready var sprint_solved_label: Label = $MainLayout/ContentArea/LeftPanel/ModeHUD/SprintHUD/SolvedLabel

# Streak HUD elements
@onready var streak_hud: Control = $MainLayout/ContentArea/LeftPanel/ModeHUD/StreakHUD
@onready var streak_counter: StreakCounter = $MainLayout/ContentArea/LeftPanel/ModeHUD/StreakHUD/StreakCounter
@onready var streak_rating_label: Label = $MainLayout/ContentArea/LeftPanel/ModeHUD/StreakHUD/RatingLabel

# Daily HUD elements
@onready var daily_hud: Control = $MainLayout/ContentArea/LeftPanel/ModeHUD/DailyHUD
@onready var daily_progress: DailyProgress = $MainLayout/ContentArea/LeftPanel/ModeHUD/DailyHUD/DailyProgress
@onready var daily_puzzle_label: Label = $MainLayout/ContentArea/LeftPanel/ModeHUD/DailyHUD/PuzzleLabel

# Thinking indicator
@onready var thinking_indicator: ThinkingIndicator = $MainLayout/ContentArea/LeftPanel/ModeHUD/ThinkingIndicator

# Result modal
@onready var result_modal: PuzzleResultModal = $PuzzleResultModal

# State
var game_started: bool = false
var puzzle_count: int = 0  # Track how many puzzles we've seen this session
var moves_made: Array[String] = []  # Track moves made in current puzzle


func _ready() -> void:
	_connect_ui_signals()
	_hide_all_huds()
	_init_debug_panel()

	# Auto-initialize in practice mode when running scene directly (for testing)
	if not game_started:
		call_deferred("_auto_init_for_testing")


func _connect_ui_signals() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)

	# Button bar signals
	if undo_btn:
		undo_btn.pressed.connect(_on_undo_pressed)
		undo_btn.disabled = true
	if redo_btn:
		redo_btn.pressed.connect(_on_redo_pressed)
		redo_btn.disabled = true
	if hint_btn:
		hint_btn.pressed.connect(_on_hint_pressed)
	if solution_btn:
		solution_btn.pressed.connect(_on_solution_pressed)
	if skip_btn:
		skip_btn.pressed.connect(_on_skip_pressed)
	if next_btn:
		next_btn.pressed.connect(_on_next_puzzle_pressed)
		next_btn.disabled = true

	# Options panel signals
	if flip_board_btn:
		flip_board_btn.pressed.connect(_on_flip_board_pressed)


func _auto_init_for_testing() -> void:
	# Only auto-init if running scene directly and not already initialized
	if game_started:
		return
	print("[PuzzleScreen] Auto-initializing in PRACTICE mode for testing")
	initialize(PuzzleController.GameMode.PRACTICE, {})


## Initialize the puzzle screen with a specific mode.
func initialize(mode: PuzzleController.GameMode, settings: Dictionary = {}) -> void:
	current_mode = mode
	mode_settings = settings

	_setup_puzzle_controller()
	_setup_mode_instance()
	_show_mode_hud(mode)
	_update_buttons_for_mode(mode)
	_start_game()


func _setup_puzzle_controller() -> void:
	puzzle_controller = PuzzleController.new()
	add_child(puzzle_controller)

	# Connect puzzle controller signals (always connect these)
	puzzle_controller.puzzle_loaded.connect(_on_puzzle_loaded)
	puzzle_controller.move_made.connect(_on_move_made)
	puzzle_controller.puzzle_completed.connect(_on_puzzle_completed)
	puzzle_controller.opponent_moving.connect(_on_opponent_moving)
	puzzle_controller.state_changed.connect(_on_state_changed)

	# Connect chess board signals
	if chess_board:
		if not chess_board.move_attempted.is_connected(_on_move_attempted):
			chess_board.move_attempted.connect(_on_move_attempted)
	else:
		push_error("[PuzzleScreen] chess_board is null during setup!")

	# Connect thinking indicator
	puzzle_controller.analysis_started.connect(_on_analysis_started)
	puzzle_controller.analysis_completed.connect(_on_analysis_completed)

	# Connect move history for undo/redo buttons
	puzzle_controller.history_changed.connect(_on_history_changed)

	# Connect modal signals
	puzzle_controller.incorrect_move.connect(_on_incorrect_move)
	puzzle_controller.puzzle_solved.connect(_on_puzzle_solved)

	# Connect modal button signals
	if result_modal:
		if not result_modal.try_again_pressed.is_connected(_on_modal_try_again):
			result_modal.try_again_pressed.connect(_on_modal_try_again)
		if not result_modal.next_puzzle_pressed.is_connected(_on_modal_next_puzzle):
			result_modal.next_puzzle_pressed.connect(_on_modal_next_puzzle)
		if not result_modal.show_solution_pressed.is_connected(_on_modal_show_solution):
			result_modal.show_solution_pressed.connect(_on_modal_show_solution)
	else:
		push_error("[PuzzleScreen] result_modal is null during setup!")


func _setup_mode_instance() -> void:
	match current_mode:
		PuzzleController.GameMode.PRACTICE:
			practice_mode = PracticeMode.new()
			add_child(practice_mode)
			practice_mode.initialize(puzzle_controller, chess_board, UserData.db)
			practice_mode.hint_displayed.connect(_on_hint_displayed)
			practice_mode.solution_completed.connect(_on_solution_completed)

		PuzzleController.GameMode.SPRINT:
			sprint_mode = SprintMode.new()
			add_child(sprint_mode)
			sprint_mode.initialize(puzzle_controller, UserData.db)
			sprint_mode.timer_updated.connect(_on_timer_updated)
			sprint_mode.strike_added.connect(_on_strike_added)
			sprint_mode.puzzles_solved_updated.connect(_on_sprint_solved_updated)
			sprint_mode.game_ended.connect(_on_sprint_ended)

		PuzzleController.GameMode.STREAK:
			streak_mode = StreakMode.new()
			add_child(streak_mode)
			streak_mode.initialize(puzzle_controller, UserData.db)
			streak_mode.streak_updated.connect(_on_streak_updated)
			streak_mode.rating_updated.connect(_on_rating_updated)
			streak_mode.game_ended.connect(_on_streak_ended)

		PuzzleController.GameMode.DAILY:
			daily_mode = DailyMode.new()
			add_child(daily_mode)
			daily_mode.initialize(puzzle_controller, UserData.db)
			daily_mode.next_puzzle_started.connect(_on_daily_next_puzzle)
			daily_mode.puzzle_completed.connect(_on_daily_puzzle_completed)
			daily_mode.daily_completed.connect(_on_daily_completed)
			daily_mode.already_completed_today.connect(_on_daily_already_completed)


func _start_game() -> void:
	game_started = true

	match current_mode:
		PuzzleController.GameMode.PRACTICE:
			practice_mode.set_settings(mode_settings)
			practice_mode.start_practice()

		PuzzleController.GameMode.SPRINT:
			# Just pass settings directly - start_game handles parsing
			sprint_mode.start_game(mode_settings)

		PuzzleController.GameMode.STREAK:
			var starting_rating = mode_settings.get("starting_rating", 1200)
			streak_mode.start_streak(starting_rating)

		PuzzleController.GameMode.DAILY:
			daily_mode.start_daily()


func _hide_all_huds() -> void:
	if sprint_hud:
		sprint_hud.visible = false
	if streak_hud:
		streak_hud.visible = false
	if daily_hud:
		daily_hud.visible = false


func _show_mode_hud(mode: PuzzleController.GameMode) -> void:
	_hide_all_huds()

	match mode:
		PuzzleController.GameMode.PRACTICE:
			pass  # No special HUD, buttons handle it
		PuzzleController.GameMode.SPRINT:
			if sprint_hud:
				sprint_hud.visible = true
		PuzzleController.GameMode.STREAK:
			if streak_hud:
				streak_hud.visible = true
		PuzzleController.GameMode.DAILY:
			if daily_hud:
				daily_hud.visible = true


func _update_buttons_for_mode(mode: PuzzleController.GameMode) -> void:
	# Show/hide buttons based on mode
	match mode:
		PuzzleController.GameMode.PRACTICE:
			if hint_btn: hint_btn.visible = true
			if solution_btn: solution_btn.visible = true
			if skip_btn: skip_btn.visible = true
			if next_btn: next_btn.visible = true
		PuzzleController.GameMode.SPRINT:
			if hint_btn: hint_btn.visible = false
			if solution_btn: solution_btn.visible = false
			if skip_btn: skip_btn.visible = false
			if next_btn: next_btn.visible = false
		PuzzleController.GameMode.STREAK:
			if hint_btn: hint_btn.visible = false
			if solution_btn: solution_btn.visible = false
			if skip_btn: skip_btn.visible = false
			if next_btn: next_btn.visible = false
		PuzzleController.GameMode.DAILY:
			if hint_btn: hint_btn.visible = true
			if solution_btn: solution_btn.visible = true
			if skip_btn: skip_btn.visible = false
			if next_btn: next_btn.visible = false


# Debug panel functions
func _init_debug_panel() -> void:
	# Show build number to verify we're running latest code
	if debug_build_time:
		debug_build_time.text = "Build: %d" % BUILD
		print("[PuzzleScreen] Build: %d" % BUILD)

	# Initialize with DB version
	if debug_db_version:
		var version = UserData.get_puzzle_version() if UserData else "unknown"
		debug_db_version.text = "DB Version: %s" % version


func _update_debug_panel() -> void:
	if not puzzle_controller:
		return

	var puzzle = puzzle_controller.current_puzzle
	if not puzzle:
		return

	# Puzzle ID
	if debug_puzzle_id:
		debug_puzzle_id.text = "Puzzle ID: %s" % puzzle.id

	# Puzzle number in session
	if debug_puzzle_number:
		debug_puzzle_number.text = "Puzzle #: %d" % puzzle_count

	# Original FEN
	if debug_fen:
		debug_fen.text = "FEN: %s" % puzzle.fen

	# Move index
	if debug_move_index:
		var total_moves = puzzle.solution_moves.size() if puzzle.solution_moves else 0
		debug_move_index.text = "Move Index: %d / %d" % [puzzle_controller.move_index, total_moves]

	# Expected move
	if debug_expected_move:
		var expected = "--"
		if puzzle.solution_moves and puzzle_controller.move_index < puzzle.solution_moves.size():
			expected = puzzle.solution_moves[puzzle_controller.move_index]
		debug_expected_move.text = "Expected: %s" % expected

	# Current FEN (live board state)
	if debug_current_fen:
		var current_fen = ChessLogic.to_fen() if ChessLogic else "unknown"
		debug_current_fen.text = "Current FEN: %s" % current_fen

	# Moves made
	if debug_moves_list:
		if moves_made.is_empty():
			debug_moves_list.text = "(none)"
		else:
			debug_moves_list.text = " ".join(moves_made)

	# Solution moves (show all for debugging)
	if debug_solution_list:
		if puzzle.solution_moves and not puzzle.solution_moves.is_empty():
			debug_solution_list.text = " ".join(puzzle.solution_moves)
		else:
			debug_solution_list.text = "(none)"

	# Puzzle state
	if debug_puzzle_state:
		var state_name = "UNKNOWN"
		match puzzle_controller.current_state:
			PuzzleController.PuzzleState.LOADING:
				state_name = "LOADING"
			PuzzleController.PuzzleState.PLAYER_TURN:
				state_name = "PLAYER_TURN"
			PuzzleController.PuzzleState.OPPONENT_TURN:
				state_name = "OPPONENT_TURN"
			PuzzleController.PuzzleState.COMPLETED_SUCCESS:
				state_name = "COMPLETED_SUCCESS"
			PuzzleController.PuzzleState.COMPLETED_FAILED:
				state_name = "COMPLETED_FAILED"
			PuzzleController.PuzzleState.SHOWING_SOLUTION:
				state_name = "SHOWING_SOLUTION"
			PuzzleController.PuzzleState.GAME_OVER:
				state_name = "GAME_OVER"
		debug_puzzle_state.text = "State: %s" % state_name

	# Attempts
	if debug_attempts:
		debug_attempts.text = "Attempts: %d" % puzzle_controller.attempt_count

	# Rating
	if debug_rating:
		debug_rating.text = "Rating: %d" % puzzle.rating

	# Mate in
	if debug_mate_in:
		debug_mate_in.text = "Mate In: %d" % puzzle.mate_in


# Move handling
func _on_move_attempted(from: int, to: int) -> void:
	if puzzle_controller:
		# TODO: Handle pawn promotion - for now pass EMPTY (no promotion)
		puzzle_controller.submit_move(from, to, ChessLogic.EMPTY)


func _on_puzzle_loaded(puzzle: PuzzleData) -> void:
	print("[PuzzleScreen] _on_puzzle_loaded called, FEN: ", puzzle.fen if puzzle else "NULL PUZZLE")

	# First determine player color and set board orientation
	_setup_board_orientation(puzzle)

	# Then set up the position with correct orientation
	if chess_board:
		chess_board.set_board_position(puzzle.fen)
	else:
		print("[PuzzleScreen] ERROR: chess_board is null!")

	# Update the puzzle info display
	_update_puzzle_info(puzzle)

	# Disable Next button when new puzzle loads (re-enabled when solved)
	if next_btn:
		next_btn.disabled = true

	# Update debug panel
	puzzle_count += 1
	moves_made.clear()
	_update_debug_panel()


func _setup_board_orientation(puzzle: PuzzleData) -> void:
	if not chess_board:
		return

	# In Lichess puzzles: first move in solution is opponent's setup/blunder
	# So player is the OPPOSITE of who moves first in the FEN
	var fen_parts = puzzle.fen.split(" ")
	var first_to_move = "w"
	if fen_parts.size() > 1:
		first_to_move = fen_parts[1]

	# Player is opposite of who moves first (opponent makes setup move)
	var player_is_black = (first_to_move == "w")

	# Flip board so player's pieces are at the bottom
	chess_board.flipped = player_is_black


func _on_move_made(from: int, to: int, _is_correct: bool) -> void:
	if chess_board:
		chess_board.refresh_position()

	# Track move for debug panel
	var move_uci = ChessLogic.squares_to_uci(from, to, ChessLogic.EMPTY)
	moves_made.append(move_uci)
	_update_debug_panel()


func _on_puzzle_completed(_success: bool, _attempts: int) -> void:
	pass  # Mode handlers deal with this


func _on_opponent_moving(from: int, to: int) -> void:
	if chess_board:
		# Block input during opponent's animation
		chess_board.input_blocked = true
		chess_board.animate_move(from, to)


func _on_state_changed(_old_state: PuzzleController.PuzzleState, new_state: PuzzleController.PuzzleState) -> void:
	# Update debug panel to show current state
	_update_debug_panel()

	if not chess_board:
		return

	var state_names = ["LOADING", "PLAYER_TURN", "OPPONENT_TURN", "COMPLETED_SUCCESS",
					   "COMPLETED_FAILED", "SHOWING_SOLUTION", "GAME_OVER"]
	var state_name = state_names[new_state] if new_state < state_names.size() else str(new_state)
	print("[PuzzleScreen] State changed to %s, input_blocked=%s" % [state_name, chess_board.input_blocked])

	match new_state:
		PuzzleController.PuzzleState.PLAYER_TURN:
			# Unblock input when it becomes the player's turn
			print("[PuzzleScreen] Unblocking input for player turn")
			chess_board.input_blocked = false
			# Also refresh the board to ensure it's in sync with ChessLogic
			chess_board.refresh_position()
			print("[PuzzleScreen] After unblock: input_blocked=%s" % chess_board.input_blocked)

		PuzzleController.PuzzleState.OPPONENT_TURN:
			# Block input during opponent's turn
			print("[PuzzleScreen] Blocking input for opponent turn")
			chess_board.input_blocked = true

		PuzzleController.PuzzleState.LOADING:
			# Block input while loading
			chess_board.input_blocked = true

		_:
			pass  # Other states don't change input blocking


func _update_puzzle_info(puzzle: PuzzleData) -> void:
	if puzzle_info_label:
		# Determine the player's color
		# In Lichess puzzles: first move in solution is opponent's setup/blunder
		# So player is the OPPOSITE of who moves first in the FEN
		var fen_parts = puzzle.fen.split(" ")
		var first_to_move = "w"
		if fen_parts.size() > 1:
			first_to_move = fen_parts[1]

		# Player is opposite of who moves first (opponent makes setup move)
		var player_color = "White" if first_to_move == "b" else "Black"

		puzzle_info_label.text = "#%s  |  Play as %s  |  Mate in %d  |  Rating: %d" % [
			puzzle.id, player_color, puzzle.mate_in, puzzle.rating
		]


# Button handlers
func _on_undo_pressed() -> void:
	if puzzle_controller:
		puzzle_controller.undo_move()
		if chess_board:
			chess_board.refresh_position()


func _on_redo_pressed() -> void:
	if puzzle_controller:
		puzzle_controller.redo_move()
		if chess_board:
			chess_board.refresh_position()


func _on_flip_board_pressed() -> void:
	if chess_board:
		chess_board.flip_board()


func _on_hint_pressed() -> void:
	if practice_mode:
		practice_mode.show_hint()


func _on_solution_pressed() -> void:
	if practice_mode:
		practice_mode.show_solution()


func _on_skip_pressed() -> void:
	if practice_mode:
		practice_mode.skip_puzzle()
	# Disable Next button when skipping to a new puzzle
	if next_btn:
		next_btn.disabled = true


func _on_next_puzzle_pressed() -> void:
	if practice_mode:
		practice_mode.load_next_puzzle()
	# Disable the button after clicking
	if next_btn:
		next_btn.disabled = true


func _on_hint_displayed(_square: int) -> void:
	# Visual feedback handled by practice_mode directly on chess_board
	pass


func _on_solution_completed() -> void:
	# Enable Next button after solution is shown
	if next_btn:
		next_btn.disabled = false


# Sprint mode handlers
func _on_timer_updated(time_remaining: float) -> void:
	if timer_display:
		timer_display.update_time(time_remaining)


func _on_strike_added(total_strikes: int) -> void:
	if strike_indicator:
		strike_indicator.set_strikes(total_strikes)


func _on_sprint_solved_updated(count: int) -> void:
	if sprint_solved_label:
		sprint_solved_label.text = "Solved: %d" % count


func _on_sprint_ended(reason: String, stats: Dictionary) -> void:
	# Show sprint results
	game_started = false
	_show_sprint_results(reason, stats)


func _show_sprint_results(reason: String, stats: Dictionary) -> void:
	# Emit to main to show results screen
	var results_data = {
		"mode": "sprint",
		"reason": reason,
		"stats": stats
	}
	# The main scene will handle showing the results
	get_tree().call_group("game_manager", "show_results", results_data)


# Streak mode handlers
func _on_streak_updated(streak: int) -> void:
	if streak_counter:
		streak_counter.set_streak(streak)


func _on_rating_updated(rating: int) -> void:
	if streak_rating_label:
		streak_rating_label.text = "Rating: %d" % rating


func _on_streak_ended(stats: Dictionary) -> void:
	game_started = false
	_show_streak_results(stats)


func _show_streak_results(stats: Dictionary) -> void:
	var results_data = {
		"mode": "streak",
		"stats": stats
	}
	get_tree().call_group("game_manager", "show_results", results_data)


# Daily mode handlers
func _on_daily_next_puzzle(index: int, total: int) -> void:
	if daily_puzzle_label:
		daily_puzzle_label.text = "Puzzle %d of %d" % [index + 1, total]
	if daily_progress:
		daily_progress.set_current(index)


func _on_daily_puzzle_completed(index: int, solved: bool, _perfect: bool) -> void:
	if daily_progress:
		daily_progress.set_result(index, solved)


func _on_daily_completed(results: Array, score: float, streak: int) -> void:
	game_started = false
	_show_daily_results(results, score, streak)


func _on_daily_already_completed() -> void:
	# Go back to menu - today's already done
	main_menu_requested.emit()


func _show_daily_results(results: Array, score: float, streak: int) -> void:
	var share_text = daily_mode.generate_share_text() if daily_mode else ""
	var results_data = {
		"mode": "daily",
		"results": results,
		"score": score,
		"streak": streak,
		"share_text": share_text
	}
	get_tree().call_group("game_manager", "show_results", results_data)


# Navigation
func _on_back_pressed() -> void:
	if _should_confirm_quit():
		_show_quit_confirmation()
	else:
		_quit_game()


func _should_confirm_quit() -> bool:
	# Confirm quit if in a timed/scored game mode
	return game_started and current_mode != PuzzleController.GameMode.PRACTICE


func _show_quit_confirmation() -> void:
	# For now, just quit - TODO: add confirmation dialog
	_quit_game()


func _quit_game() -> void:
	_cleanup_mode()
	main_menu_requested.emit()


func _cleanup_mode() -> void:
	if practice_mode:
		practice_mode.queue_free()
		practice_mode = null
	if sprint_mode:
		sprint_mode.queue_free()
		sprint_mode = null
	if streak_mode:
		streak_mode.queue_free()
		streak_mode = null
	if daily_mode:
		daily_mode.queue_free()
		daily_mode = null
	if puzzle_controller:
		puzzle_controller.queue_free()
		puzzle_controller = null


## Handle back navigation (called from main.gd).
func handle_back() -> bool:
	if _should_confirm_quit():
		_show_quit_confirmation()
		return true
	return false


# Thinking indicator handlers
func _on_analysis_started() -> void:
	if thinking_indicator:
		thinking_indicator.start_thinking()


func _on_analysis_completed() -> void:
	if thinking_indicator:
		thinking_indicator.stop_thinking()


# Move navigation handlers (undo/redo)
func _on_history_changed(can_undo: bool, can_redo: bool) -> void:
	if undo_btn:
		undo_btn.disabled = not can_undo
	if redo_btn:
		redo_btn.disabled = not can_redo


# Modal handlers
func _on_incorrect_move(_can_retry: bool, _can_skip: bool) -> void:
	# For practice mode, automatically revert the incorrect move and let player try again
	if current_mode == PuzzleController.GameMode.PRACTICE:
		# Wait briefly to show the incorrect move, then revert
		await get_tree().create_timer(0.5).timeout
		if puzzle_controller:
			puzzle_controller.revert_incorrect_move()
		if chess_board:
			chess_board.refresh_position()
		return

	# For other modes, show modal (disabled for now, focusing on practice mode)
	# TODO: Re-enable modal for other modes once practice mode is working
	pass


func _on_puzzle_solved() -> void:
	# For practice mode, just enable the Next button instead of showing modal
	if current_mode == PuzzleController.GameMode.PRACTICE:
		if next_btn:
			next_btn.disabled = false
		return

	# For other modes, show modal (disabled for now, focusing on practice mode)
	# TODO: Re-enable modal for other modes once practice mode is working
	pass


func _on_modal_try_again() -> void:
	if puzzle_controller:
		puzzle_controller.revert_incorrect_move()
		if chess_board:
			chess_board.refresh_position()


func _on_modal_next_puzzle() -> void:
	_advance_to_next_puzzle()


func _on_modal_show_solution() -> void:
	if puzzle_controller:
		puzzle_controller.revert_incorrect_move()
		puzzle_controller.show_solution()
		if chess_board:
			chess_board.refresh_position()


func _advance_to_next_puzzle() -> void:
	match current_mode:
		PuzzleController.GameMode.PRACTICE:
			if practice_mode:
				practice_mode.load_next_puzzle()
		PuzzleController.GameMode.SPRINT:
			if sprint_mode:
				sprint_mode._load_next_puzzle()
		PuzzleController.GameMode.STREAK:
			# Streak mode - if we got here after incorrect, game is over
			if puzzle_controller and puzzle_controller.current_state == PuzzleController.PuzzleState.COMPLETED_FAILED:
				if streak_mode:
					streak_mode.end_game()
			else:
				if streak_mode:
					streak_mode._load_next_puzzle()
		PuzzleController.GameMode.DAILY:
			if daily_mode:
				daily_mode._load_current_puzzle()
