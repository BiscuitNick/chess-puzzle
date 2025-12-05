class_name PracticeMode
extends Node
## Practice mode implementation with puzzle filtering, hints, and solution reveal.

## Emitted when settings are changed
signal settings_changed(settings: Dictionary)

## Emitted when streak count changes
signal streak_updated(streak: int)

## Emitted when puzzle stats update (solved count, hints used)
signal puzzle_stats_updated(solved: int, hints: int)

## Emitted when a hint is displayed
signal hint_displayed(square: int)

## Emitted when solution reveal starts
signal solution_started()

## Emitted for each solution move shown
signal solution_move_shown(move_index: int, from: int, to: int)

## Emitted when solution reveal completes
signal solution_completed()

## Emitted when no puzzles match current criteria
signal no_puzzles_available()

# Current game settings
var current_settings: Dictionary = {
	"mate_depth": 0,  # 0 = All, 1-5 = specific depth
	"min_rating": 800,
	"max_rating": 1600,
	"order": "random",  # "random" or "progressive"
	"challenge_mode": false  # Enables mate depth 6+
}

# Statistics
var current_streak: int = 0
var puzzles_solved: int = 0
var hints_used: int = 0
var puzzles_attempted: int = 0

# State
var current_position_fen: String = ""
var hint_shown: bool = false
var showing_solution: bool = false

# References (set externally or via _ready)
var puzzle_controller: PuzzleController
var chess_board: ChessBoard
var db: SQLite


func _ready() -> void:
	# Try to get references from scene tree if not set
	if not puzzle_controller:
		puzzle_controller = get_node_or_null("/root/Main/PuzzleController")
	if not chess_board:
		chess_board = get_node_or_null("/root/Main/ChessBoard")


## Initialize and connect to puzzle controller signals.
func initialize(controller: PuzzleController, board: ChessBoard, database: SQLite) -> void:
	puzzle_controller = controller
	chess_board = board
	db = database

	# Connect signals
	puzzle_controller.puzzle_loaded.connect(_on_puzzle_loaded)
	puzzle_controller.move_made.connect(_on_move_made)
	puzzle_controller.puzzle_completed.connect(_on_puzzle_completed)
	puzzle_controller.state_changed.connect(_on_state_changed)


## Set practice mode settings.
func set_settings(settings: Dictionary) -> void:
	for key in settings:
		if current_settings.has(key):
			current_settings[key] = settings[key]
	settings_changed.emit(current_settings)


## Start a new practice session.
func start_practice() -> void:
	start_game(current_settings)


## Start a new practice session with the given settings.
func start_game(settings: Dictionary) -> void:
	current_settings = settings.duplicate()
	current_streak = 0
	puzzles_solved = 0
	hints_used = 0
	puzzles_attempted = 0
	hint_shown = false
	showing_solution = false

	# Set puzzle controller to practice mode
	puzzle_controller.set_mode(PuzzleController.GameMode.PRACTICE)

	settings_changed.emit(current_settings)
	load_next_puzzle()


## Load the next puzzle based on current settings.
func load_next_puzzle() -> void:
	hint_shown = false
	showing_solution = false

	var puzzle = _query_next_puzzle()
	if puzzle:
		puzzles_attempted += 1
		puzzle_controller.load_puzzle(puzzle)
	else:
		push_warning("No puzzles found matching criteria")
		no_puzzles_available.emit()


## Query database for next puzzle matching filters.
func _query_next_puzzle() -> PuzzleData:
	if not db:
		push_error("Database not initialized")
		return null

	var params: Array = [current_settings.min_rating, current_settings.max_rating]

	# Build WHERE clause for mate depth
	var mate_clause = ""
	if current_settings.mate_depth > 0:
		mate_clause = " AND mate_in = ?"
		params.append(current_settings.mate_depth)
	elif not current_settings.challenge_mode:
		mate_clause = " AND mate_in <= 5"  # Exclude 6+ unless challenge mode

	# Build ORDER clause
	var order_clause = "ORDER BY RANDOM()" if current_settings.order == "random" else "ORDER BY rating ASC"

	# Query with preference for unsolved puzzles
	var query = """
		SELECT p.* FROM puzzles p
		LEFT JOIN user_puzzle_history h ON p.id = h.puzzle_id
		WHERE p.rating BETWEEN ? AND ?%s
		AND (h.puzzle_id IS NULL OR h.result != 'solved')
		%s
		LIMIT 1
	""" % [mate_clause, order_clause]

	db.query_with_bindings(query, params)

	if db.query_result.size() > 0:
		return _row_to_puzzle_data(db.query_result[0])

	# Fallback: include solved puzzles if no unsolved available
	query = """
		SELECT * FROM puzzles
		WHERE rating BETWEEN ? AND ?%s
		%s
		LIMIT 1
	""" % [mate_clause, order_clause]

	# Reset params for fallback query
	params = [current_settings.min_rating, current_settings.max_rating]
	if current_settings.mate_depth > 0:
		params.append(current_settings.mate_depth)

	db.query_with_bindings(query, params)

	if db.query_result.size() > 0:
		return _row_to_puzzle_data(db.query_result[0])

	return null


## Convert database row to PuzzleData object.
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


## Show a hint - highlight the correct piece to move.
func show_hint() -> void:
	if hint_shown or showing_solution:
		return

	if not puzzle_controller.current_puzzle:
		return

	# Get current expected move from puzzle solution
	var expected_move_index = puzzle_controller.move_index
	var expected_move_uci = puzzle_controller.current_puzzle.get_current_move(expected_move_index)

	if expected_move_uci.is_empty():
		return

	# Parse the expected move to get source square
	var move_data = ChessLogic.uci_to_squares(expected_move_uci)
	var hint_square = move_data["from"]

	if hint_square < 0:
		return

	# Highlight the piece that should move
	if chess_board:
		chess_board.set_hint_highlight(hint_square)

	hint_displayed.emit(hint_square)

	hints_used += 1
	hint_shown = true
	puzzle_stats_updated.emit(puzzles_solved, hints_used)


## Show the solution - animate remaining moves.
func show_solution() -> void:
	if showing_solution:
		return

	showing_solution = true
	solution_started.emit()

	# Get remaining solution moves
	var current_index = puzzle_controller.move_index
	var solution_moves = puzzle_controller.current_puzzle.solution_moves

	# Animate each remaining move sequentially
	for i in range(current_index, solution_moves.size()):
		var move_uci = solution_moves[i]
		var move_data = ChessLogic.uci_to_squares(move_uci)

		if move_data["from"] < 0:
			continue

		# Emit signal for UI feedback
		solution_move_shown.emit(i, move_data["from"], move_data["to"])

		# Animate the move on board
		if chess_board:
			chess_board.animate_move(move_data["from"], move_data["to"])
			await chess_board.move_animation_finished

		# Make the move in logic
		ChessLogic.make_move(move_data["from"], move_data["to"], move_data["promotion"])

		# Brief pause between moves for readability
		await get_tree().create_timer(0.4).timeout

	solution_completed.emit()
	showing_solution = false

	# Reset streak since solution was shown
	current_streak = 0
	streak_updated.emit(current_streak)


## Skip current puzzle and load next.
func skip_puzzle() -> void:
	# Reset streak on skip
	current_streak = 0
	streak_updated.emit(current_streak)
	load_next_puzzle()


## Get current hint (the correct move UCI) for external use.
func get_hint_move() -> String:
	if not puzzle_controller.current_puzzle:
		return ""
	return puzzle_controller.current_puzzle.get_current_move(puzzle_controller.move_index)


## Get current stats as a dictionary.
func get_stats() -> Dictionary:
	return {
		"puzzles_solved": puzzles_solved,
		"puzzles_attempted": puzzles_attempted,
		"current_streak": current_streak,
		"hints_used": hints_used,
		"accuracy": float(puzzles_solved) / max(1, puzzles_attempted) * 100.0
	}


# Signal handlers

func _on_puzzle_loaded(puzzle: PuzzleData) -> void:
	# Store initial position for potential rewind
	current_position_fen = ChessLogic.to_fen()
	hint_shown = false


func _on_move_made(from: int, to: int, is_correct: bool) -> void:
	# Clear hint highlight after any move
	if chess_board:
		chess_board.clear_hint_highlight()
	hint_shown = false

	if not is_correct:
		# In practice mode, rewind to position before wrong move
		# The puzzle controller handles the state, we just need to restore visuals
		if current_position_fen and chess_board:
			# Position is rewound by puzzle controller in practice mode
			# Just update the stored FEN
			await get_tree().create_timer(0.5).timeout
			current_position_fen = ChessLogic.to_fen()


func _on_puzzle_completed(success: bool, attempts: int) -> void:
	if success:
		puzzles_solved += 1
		current_streak += 1
		streak_updated.emit(current_streak)
		puzzle_stats_updated.emit(puzzles_solved, hints_used)
	else:
		current_streak = 0
		streak_updated.emit(current_streak)


func _on_state_changed(old_state: PuzzleController.PuzzleState, new_state: PuzzleController.PuzzleState) -> void:
	# Store position when entering player turn (for rewind on wrong move)
	if new_state == PuzzleController.PuzzleState.PLAYER_TURN:
		current_position_fen = ChessLogic.to_fen()
