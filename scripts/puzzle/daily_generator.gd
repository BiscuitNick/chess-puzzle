class_name DailyGenerator
extends RefCounted
## Generates deterministic daily puzzles using hash-based selection.
## All players worldwide get the same 5 puzzles on the same day.

# Rating brackets for 5 daily puzzles (increasing difficulty)
const DAILY_RATING_BRACKETS = [
	{"min": 800, "max": 1000, "name": "Warm-up"},
	{"min": 1000, "max": 1300, "name": "Easy"},
	{"min": 1300, "max": 1600, "name": "Medium"},
	{"min": 1600, "max": 1900, "name": "Hard"},
	{"min": 1900, "max": 2200, "name": "Challenge"}
]

# Epoch date for calculating day number
const EPOCH_DATE = {"year": 2024, "month": 1, "day": 1}

# Database reference
var db: SQLite


func _init(database: SQLite = null) -> void:
	db = database


## Get today's date as a string (YYYY-MM-DD).
static func get_date_string() -> String:
	var date = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]


## Get a specific date as a string.
static func date_to_string(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]


## Calculate day number since epoch (for share text).
static func get_day_number(date_string: String = "") -> int:
	if date_string.is_empty():
		date_string = get_date_string()

	var parts = date_string.split("-")
	if parts.size() != 3:
		return 0

	var year = int(parts[0])
	var month = int(parts[1])
	var day = int(parts[2])

	# Simple day calculation (not accounting for leap years precisely, but consistent)
	var epoch_days = EPOCH_DATE.year * 365 + EPOCH_DATE.month * 30 + EPOCH_DATE.day
	var current_days = year * 365 + month * 30 + day

	return current_days - epoch_days


## Get all 5 daily puzzles for today (or specified date).
func get_daily_puzzles(date_string: String = "") -> Array[PuzzleData]:
	if date_string.is_empty():
		date_string = get_date_string()

	var puzzles: Array[PuzzleData] = []

	for i in range(DAILY_RATING_BRACKETS.size()):
		var bracket = DAILY_RATING_BRACKETS[i]
		var puzzle = _get_deterministic_puzzle(date_string, i, bracket)
		if puzzle:
			puzzles.append(puzzle)
		else:
			push_warning("No puzzle found for bracket %d on %s" % [i, date_string])

	return puzzles


## Get a single puzzle deterministically based on date, index, and rating bracket.
func _get_deterministic_puzzle(date_string: String, index: int, bracket: Dictionary) -> PuzzleData:
	if not db:
		push_error("Database not initialized")
		return null

	# Query all puzzle IDs within the rating bracket
	var query = """
		SELECT id FROM puzzles
		WHERE rating BETWEEN ? AND ?
		AND mate_in <= 5
	"""

	db.query_with_bindings(query, [bracket.min, bracket.max])

	if db.query_result.is_empty():
		push_warning("No puzzles in bracket %d-%d" % [bracket.min, bracket.max])
		return null

	# Score each puzzle ID deterministically using hash
	var scored_ids: Array[Dictionary] = []
	for row in db.query_result:
		var puzzle_id = str(row.id)
		var hash_input = date_string + "-" + str(index) + "-" + puzzle_id
		var score = hash(hash_input)
		scored_ids.append({"id": puzzle_id, "score": score})

	# Sort by score
	scored_ids.sort_custom(func(a, b): return a.score < b.score)

	# Select first puzzle ID
	var selected_id = scored_ids[0].id

	# Fetch full puzzle data
	return _fetch_puzzle_by_id(selected_id)


## Fetch complete puzzle data by ID.
func _fetch_puzzle_by_id(puzzle_id: String) -> PuzzleData:
	var query = "SELECT * FROM puzzles WHERE id = ?"
	db.query_with_bindings(query, [puzzle_id])

	if db.query_result.is_empty():
		return null

	return _row_to_puzzle_data(db.query_result[0])


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


## Check if puzzles are available for the specified bracket.
func has_puzzles_in_bracket(bracket_index: int) -> bool:
	if bracket_index < 0 or bracket_index >= DAILY_RATING_BRACKETS.size():
		return false

	var bracket = DAILY_RATING_BRACKETS[bracket_index]
	var query = """
		SELECT COUNT(*) as count FROM puzzles
		WHERE rating BETWEEN ? AND ?
		AND mate_in <= 5
	"""

	db.query_with_bindings(query, [bracket.min, bracket.max])

	if not db.query_result.is_empty():
		return db.query_result[0].count > 0

	return false
