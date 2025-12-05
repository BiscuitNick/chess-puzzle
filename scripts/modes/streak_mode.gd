class_name StreakMode
extends Node
## Streak mode with progressive difficulty and one-wrong-move-ends-run mechanic.

## Emitted when streak count changes
signal streak_updated(count: int)

## Emitted when peak rating is updated
signal peak_rating_updated(rating: int)

## Emitted when game ends
signal game_over(final_stats: Dictionary)

## Emitted when requesting next puzzle
signal next_puzzle_requested()

# Starting difficulty presets
const DIFFICULTY_BEGINNER: int = 800
const DIFFICULTY_INTERMEDIATE: int = 1200
const DIFFICULTY_ADVANCED: int = 1600
const DIFFICULTY_EXPERT: int = 2000

# Rating increment range
const MIN_RATING_INCREMENT: int = 25
const MAX_RATING_INCREMENT: int = 50

# State variables
var streak_count: int = 0
var start_rating: int = DIFFICULTY_INTERMEDIATE
var current_rating: int = DIFFICULTY_INTERMEDIATE
var peak_rating: int = 0
var is_running: bool = false

# Failed puzzle tracking
var failed_puzzle: PuzzleData = null
var solved_puzzle_ids: Array[String] = []

# References
var puzzle_controller: PuzzleController
var db: SQLite


## Initialize and connect to puzzle controller.
func initialize(controller: PuzzleController, database: SQLite) -> void:
	puzzle_controller = controller
	db = database

	puzzle_controller.move_made.connect(_on_move_made)
	puzzle_controller.puzzle_completed.connect(_on_puzzle_completed)


## Start a new streak game with given starting rating.
func start_game(settings: Dictionary) -> void:
	# Parse starting rating from settings
	var difficulty = settings.get("difficulty", "intermediate")
	match difficulty:
		"beginner":
			start_rating = DIFFICULTY_BEGINNER
		"intermediate":
			start_rating = DIFFICULTY_INTERMEDIATE
		"advanced":
			start_rating = DIFFICULTY_ADVANCED
		"expert":
			start_rating = DIFFICULTY_EXPERT
		"custom":
			start_rating = settings.get("start_rating", DIFFICULTY_INTERMEDIATE)

	# Reset state
	streak_count = 0
	current_rating = start_rating
	peak_rating = 0
	is_running = true
	failed_puzzle = null
	solved_puzzle_ids.clear()

	# Set puzzle controller mode
	puzzle_controller.set_mode(PuzzleController.GameMode.STREAK)

	# Load first puzzle
	_load_next_puzzle()


## Calculate next rating with random increment.
func get_next_rating() -> int:
	return current_rating + randi_range(MIN_RATING_INCREMENT, MAX_RATING_INCREMENT)


## Handle successful puzzle solve.
func _on_puzzle_solved() -> void:
	# Track solved puzzle
	if puzzle_controller.current_puzzle:
		solved_puzzle_ids.append(puzzle_controller.current_puzzle.id)

	# Update peak rating before incrementing
	if current_rating > peak_rating:
		peak_rating = current_rating
		peak_rating_updated.emit(peak_rating)

	# Increment streak
	streak_count += 1
	streak_updated.emit(streak_count)

	# Get next rating
	current_rating = get_next_rating()

	# Auto-advance disabled - modal handles progression
	# TODO: Re-enable auto-advance once modal issues are resolved (see BACKLOG.md)
	# next_puzzle_requested.emit()
	# _load_next_puzzle()


## End the streak run.
func end_game() -> void:
	is_running = false

	# Store the failed puzzle
	failed_puzzle = puzzle_controller.current_puzzle

	var final_stats = get_final_stats()
	game_over.emit(final_stats)


## Get final game statistics.
func get_final_stats() -> Dictionary:
	return {
		"streak_count": streak_count,
		"start_rating": start_rating,
		"peak_rating": peak_rating,
		"failed_puzzle": failed_puzzle,
		"puzzles_solved": streak_count
	}


## Get current game statistics.
func get_current_stats() -> Dictionary:
	return {
		"streak_count": streak_count,
		"current_rating": current_rating,
		"start_rating": start_rating,
		"peak_rating": peak_rating
	}


## Load next puzzle at current rating.
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

	push_warning("No puzzles found near rating: %d" % current_rating)
	# Try with wider tolerance
	for _attempt in range(5):
		var puzzle = _query_next_puzzle(100)
		if puzzle:
			var loaded = await puzzle_controller.load_puzzle(puzzle)
			if loaded:
				return  # Success
			push_warning("Puzzle %s failed validation, trying another" % puzzle.id)
		else:
			break

	# No puzzles available, end game
	end_game()


## Query database for next puzzle near current rating.
func _query_next_puzzle(tolerance: int = 50) -> PuzzleData:
	if not db:
		push_error("Database not initialized")
		return null

	var min_rating = current_rating - tolerance
	var max_rating = current_rating + tolerance

	# Build exclusion list for already solved puzzles
	var exclusion_clause = ""
	var params: Array = [min_rating, max_rating]

	if not solved_puzzle_ids.is_empty():
		var placeholders = []
		for id in solved_puzzle_ids:
			placeholders.append("?")
			params.append(id)
		exclusion_clause = " AND id NOT IN (%s)" % ",".join(placeholders)

	var query = """
		SELECT * FROM puzzles
		WHERE rating BETWEEN ? AND ?
		AND mate_in <= 5
		%s
		ORDER BY ABS(rating - %d)
		LIMIT 1
	""" % [exclusion_clause, current_rating]

	db.query_with_bindings(query, params)

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


## Disabled - no hints in streak mode.
func show_hint() -> void:
	pass  # Hints disabled in streak mode


## Disabled - no solution reveal during gameplay in streak mode.
func show_solution() -> void:
	pass  # Solution disabled during active gameplay


# Signal handlers

func _on_move_made(_from: int, _to: int, is_correct: bool) -> void:
	if not is_running:
		return

	if not is_correct:
		# First wrong move ends the run immediately
		end_game()


func _on_puzzle_completed(success: bool, _attempts: int) -> void:
	if not is_running:
		return

	if success:
		_on_puzzle_solved()
