class_name PuzzleScreen
extends Control
## Main puzzle gameplay screen with mode-aware HUD.

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

# UI References
@onready var chess_board: ChessBoard = $GameArea/ChessBoard
@onready var back_btn: Button = $TopBar/BackButton
@onready var puzzle_info_label: Label = $TopBar/PuzzleInfo

# Practice HUD elements
@onready var practice_hud: Control = $HUD/PracticeHUD
@onready var hint_btn: Button = $HUD/PracticeHUD/HintButton
@onready var solution_btn: Button = $HUD/PracticeHUD/SolutionButton
@onready var skip_btn: Button = $HUD/PracticeHUD/SkipButton

# Sprint HUD elements
@onready var sprint_hud: Control = $HUD/SprintHUD
@onready var timer_display: TimerDisplay = $HUD/SprintHUD/TimerDisplay
@onready var strike_indicator: StrikeIndicator = $HUD/SprintHUD/StrikeIndicator
@onready var sprint_solved_label: Label = $HUD/SprintHUD/SolvedLabel

# Streak HUD elements
@onready var streak_hud: Control = $HUD/StreakHUD
@onready var streak_counter: StreakCounter = $HUD/StreakHUD/StreakCounter
@onready var streak_rating_label: Label = $HUD/StreakHUD/RatingLabel

# Daily HUD elements
@onready var daily_hud: Control = $HUD/DailyHUD
@onready var daily_progress: DailyProgress = $HUD/DailyHUD/DailyProgress
@onready var daily_puzzle_label: Label = $HUD/DailyHUD/PuzzleLabel

# Thinking indicator
@onready var thinking_indicator: Control = $HUD/ThinkingIndicator

# State
var game_started: bool = false


func _ready() -> void:
	_connect_ui_signals()
	_hide_all_huds()


func _connect_ui_signals() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if hint_btn:
		hint_btn.pressed.connect(_on_hint_pressed)
	if solution_btn:
		solution_btn.pressed.connect(_on_solution_pressed)
	if skip_btn:
		skip_btn.pressed.connect(_on_skip_pressed)


## Initialize the puzzle screen with a specific mode.
func initialize(mode: PuzzleController.GameMode, settings: Dictionary = {}) -> void:
	current_mode = mode
	mode_settings = settings

	_setup_puzzle_controller()
	_setup_mode_instance()
	_show_mode_hud(mode)
	_start_game()


func _setup_puzzle_controller() -> void:
	puzzle_controller = PuzzleController.new()
	add_child(puzzle_controller)

	# Connect to chess board
	if chess_board:
		chess_board.move_attempted.connect(_on_move_attempted)
		puzzle_controller.puzzle_loaded.connect(_on_puzzle_loaded)
		puzzle_controller.move_made.connect(_on_move_made)
		puzzle_controller.puzzle_completed.connect(_on_puzzle_completed)
		puzzle_controller.opponent_moving.connect(_on_opponent_moving)


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
			var time_limit = mode_settings.get("time_limit", 180.0)
			var difficulty = mode_settings.get("difficulty", SprintMode.DIFFICULTY_MEDIUM)
			sprint_mode.start_sprint(time_limit, difficulty)

		PuzzleController.GameMode.STREAK:
			var starting_rating = mode_settings.get("starting_rating", 1200)
			streak_mode.start_streak(starting_rating)

		PuzzleController.GameMode.DAILY:
			daily_mode.start_daily()


func _hide_all_huds() -> void:
	if practice_hud:
		practice_hud.visible = false
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
			if practice_hud:
				practice_hud.visible = true
		PuzzleController.GameMode.SPRINT:
			if sprint_hud:
				sprint_hud.visible = true
		PuzzleController.GameMode.STREAK:
			if streak_hud:
				streak_hud.visible = true
		PuzzleController.GameMode.DAILY:
			if daily_hud:
				daily_hud.visible = true


# Move handling
func _on_move_attempted(from: int, to: int, promotion: String) -> void:
	if puzzle_controller:
		puzzle_controller.try_move(from, to, promotion)


func _on_puzzle_loaded(puzzle: PuzzleData) -> void:
	if chess_board:
		chess_board.setup_position(puzzle.fen)
	_update_puzzle_info(puzzle)


func _on_move_made(_from: int, _to: int, _is_correct: bool) -> void:
	if chess_board:
		chess_board.refresh_position()


func _on_puzzle_completed(_success: bool, _attempts: int) -> void:
	pass  # Mode handlers deal with this


func _on_opponent_moving(from: int, to: int) -> void:
	if chess_board:
		chess_board.animate_move(from, to)


func _update_puzzle_info(puzzle: PuzzleData) -> void:
	if puzzle_info_label:
		puzzle_info_label.text = "Mate in %d  |  Rating: %d" % [puzzle.mate_in, puzzle.rating]


# Practice mode handlers
func _on_hint_pressed() -> void:
	if practice_mode:
		practice_mode.show_hint()


func _on_solution_pressed() -> void:
	if practice_mode:
		practice_mode.show_solution()


func _on_skip_pressed() -> void:
	if practice_mode:
		practice_mode.skip_puzzle()


func _on_hint_displayed(_square: int) -> void:
	# Visual feedback handled by practice_mode directly on chess_board
	pass


func _on_solution_completed() -> void:
	# Auto-advance to next puzzle after brief delay
	await get_tree().create_timer(1.0).timeout
	if practice_mode:
		practice_mode.load_next_puzzle()


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
