class_name SprintMode
extends Node
## Sprint mode with countdown timer, three-strike system, and scoring.

## Emitted when timer value updates
signal timer_updated(time_remaining: float)

## Emitted when a strike is added
signal strike_added(total_strikes: int)

## Emitted when game ends
signal game_ended(reason: String, stats: Dictionary)

## Emitted when a puzzle is completed
signal puzzle_completed(solved: int, attempted: int)

## Emitted when puzzles solved count updates (alias for puzzle_completed)
signal puzzles_solved_updated(count: int)

## Emitted when requesting next puzzle
signal next_puzzle_requested()

## Emitted when puzzle needs restart
signal puzzle_restart_requested()

# Difficulty presets
const DIFFICULTY_EASY = {"min_rating": 800, "max_rating": 1200, "name": "Easy"}
const DIFFICULTY_MEDIUM = {"min_rating": 1200, "max_rating": 1600, "name": "Medium"}
const DIFFICULTY_HARD = {"min_rating": 1600, "max_rating": 2200, "name": "Hard"}

# Time limit presets (seconds)
const TIME_1_MIN = 60.0
const TIME_3_MIN = 180.0
const TIME_5_MIN = 300.0

# Timer state
var time_remaining: float = 0.0
var time_limit: float = TIME_3_MIN
var is_running: bool = false
var timer_started: bool = false

# Strike system
var strikes: int = 0
const MAX_STRIKES: int = 3

# Scoring
var puzzles_solved: int = 0
var puzzles_attempted: int = 0

# Difficulty settings
var current_difficulty: Dictionary = DIFFICULTY_MEDIUM

# References
var puzzle_controller: PuzzleController
var db: SQLite


func _process(delta: float) -> void:
	if not is_running or not timer_started:
		return

	time_remaining -= delta
	timer_updated.emit(time_remaining)

	if time_remaining <= 0:
		time_remaining = 0
		end_game("time")


## Initialize and connect to puzzle controller.
func initialize(controller: PuzzleController, database: SQLite) -> void:
	puzzle_controller = controller
	db = database

	puzzle_controller.move_made.connect(_on_move_made)
	puzzle_controller.puzzle_completed.connect(_on_puzzle_completed)
	puzzle_controller.puzzle_loaded.connect(_on_puzzle_loaded)


## Start a new sprint game with time limit and difficulty (convenience method).
func start_sprint(time_limit_secs: float, difficulty: Dictionary) -> void:
	var settings = {
		"time_limit": time_limit_secs,
		"difficulty": difficulty.get("name", "medium").to_lower()
	}
	start_game(settings)


## Start a new sprint game with given settings.
func start_game(settings: Dictionary) -> void:
	# Parse time limit
	time_limit = settings.get("time_limit", TIME_3_MIN)
	time_remaining = time_limit

	# Parse difficulty
	var difficulty_name = settings.get("difficulty", "medium")
	match difficulty_name:
		"easy":
			current_difficulty = DIFFICULTY_EASY.duplicate()
		"medium":
			current_difficulty = DIFFICULTY_MEDIUM.duplicate()
		"hard":
			current_difficulty = DIFFICULTY_HARD.duplicate()
		"custom":
			current_difficulty = {
				"min_rating": settings.get("min_rating", 1200),
				"max_rating": settings.get("max_rating", 1600),
				"name": "Custom"
			}

	# Reset state
	strikes = 0
	puzzles_solved = 0
	puzzles_attempted = 0
	is_running = false
	timer_started = false

	# Set puzzle controller mode
	puzzle_controller.set_mode(PuzzleController.GameMode.SPRINT)

	# Load first puzzle
	_load_next_puzzle()


## Start the timer (called on first puzzle load).
func start_timer() -> void:
	if not timer_started:
		timer_started = true
		is_running = true


## Pause the timer.
func pause_timer() -> void:
	is_running = false


## Resume the timer.
func resume_timer() -> void:
	if timer_started:
		is_running = true


## End the game with reason.
func end_game(reason: String) -> void:
	is_running = false

	var stats = get_current_stats()
	stats["reason"] = reason
	stats["time_limit"] = time_limit
	stats["difficulty"] = current_difficulty.name

	game_ended.emit(reason, stats)


## Get current game stats.
func get_current_stats() -> Dictionary:
	var accuracy = 0.0
	if puzzles_attempted > 0:
		accuracy = float(puzzles_solved) / float(puzzles_attempted) * 100.0

	return {
		"puzzles_solved": puzzles_solved,
		"puzzles_attempted": puzzles_attempted,
		"strikes": strikes,
		"accuracy": accuracy,
		"time_remaining": time_remaining,
		"time_used": time_limit - time_remaining
	}


## Format time as MM:SS string.
static func format_time(seconds: float) -> String:
	var total_seconds = int(max(0, seconds))
	var minutes = total_seconds / 60
	var secs = total_seconds % 60
	return "%d:%02d" % [minutes, secs]


## Load next puzzle based on current difficulty.
func _load_next_puzzle() -> void:
	# Retry up to 5 times if puzzle fails validation
	for _attempt in range(5):
		var puzzle = _query_next_puzzle()
		if puzzle:
			var loaded = await puzzle_controller.load_puzzle(puzzle)
			if loaded:
				return  # Success
			push_warning("Puzzle %s failed validation, trying another" % puzzle.id)
		else:
			break

	push_warning("No puzzles found for difficulty: %s" % current_difficulty.name)
	# End game if no puzzles available
	end_game("no_puzzles")


## Query database for next puzzle within rating range.
func _query_next_puzzle() -> PuzzleData:
	if not db:
		push_error("Database not initialized")
		return null

	var query = """
		SELECT * FROM puzzles
		WHERE rating BETWEEN ? AND ?
		AND mate_in <= 5
		ORDER BY RANDOM()
		LIMIT 1
	"""

	db.query_with_bindings(query, [current_difficulty.min_rating, current_difficulty.max_rating])

	if db.query_result.size() > 0:
		return _row_to_puzzle_data(db.query_result[0])

	return null


## Convert database row to PuzzleData.
func _row_to_puzzle_data(row: Dictionary) -> PuzzleData:
	var moves: Array[String] = []
	var raw_moves = row.get("moves", "")
	if raw_moves is String:
		for move in raw_moves.split(" "):
			if not move.is_empty():
				moves.append(move)

	var themes: Array[String] = []
	var raw_themes = row.get("themes", "")
	if raw_themes is String:
		for theme in raw_themes.split(" "):
			if not theme.is_empty():
				themes.append(theme)

	return PuzzleData.new(
		str(row.get("id", "")),
		str(row.get("fen", "")),
		moves,
		int(row.get("rating", 0)),
		int(row.get("mate_in", 0)),
		themes
	)


# Signal handlers

func _on_puzzle_loaded(_puzzle: PuzzleData) -> void:
	# Start timer on first puzzle
	start_timer()


func _on_move_made(_from: int, _to: int, is_correct: bool) -> void:
	if not is_correct:
		# Incorrect move - add strike and restart puzzle
		strikes += 1
		strike_added.emit(strikes)

		if strikes >= MAX_STRIKES:
			end_game("strikes")
		else:
			# Restart current puzzle
			puzzle_restart_requested.emit()
			await puzzle_controller.reset_puzzle()


func _on_puzzle_completed(success: bool, _attempts: int) -> void:
	puzzles_attempted += 1

	if success:
		puzzles_solved += 1
		puzzle_completed.emit(puzzles_solved, puzzles_attempted)
		puzzles_solved_updated.emit(puzzles_solved)

		# Auto-advance disabled - modal handles progression
		# TODO: Re-enable auto-advance once modal issues are resolved (see BACKLOG.md)
		# next_puzzle_requested.emit()
		# _load_next_puzzle()
