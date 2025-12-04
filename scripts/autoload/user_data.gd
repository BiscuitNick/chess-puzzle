extends Node
## User data persistence for puzzle history, statistics, and settings.

# File paths
const STATS_PATH = "user://user_stats.json"
const SETTINGS_PATH = "user://user_settings.json"
const DB_PATH = "user://puzzles.db"

# Signals
signal stats_updated()
signal settings_updated(key: String, value: Variant)

# Statistics with defaults
var stats: Dictionary = {
	"player_rating": 1200,
	"total_puzzles_solved": 0,
	"total_puzzles_failed": 0,
	"total_time_played_ms": 0,
	"practice": {"solved": 0, "failed": 0, "time_ms": 0, "hints_used": 0},
	"sprint": {"best_1min": 0, "best_3min": 0, "best_5min": 0, "games_played": 0, "puzzles_solved": 0},
	"streak": {"best_streak": 0, "best_peak_rating": 0, "games_played": 0, "total_puzzles": 0},
	"daily": {"days_played": 0, "current_streak": 0, "best_streak": 0, "perfect_days": 0, "last_completed": ""}
}

# Settings with defaults
var settings: Dictionary = {
	"sound_enabled": true,
	"music_enabled": true,
	"show_legal_moves": true,
	"auto_flip_board": true,
	"auto_promote_queen": false,
	"animation_speed": 1.0,
	"theme": "default"
}

# Database reference
var db: SQLite


func _ready() -> void:
	_init_database()
	_load_stats()
	_load_settings()


## Initialize SQLite database with user_puzzle_history table.
func _init_database() -> void:
	db = SQLite.new()
	db.path = DB_PATH
	db.open_db()

	# Create user_puzzle_history table if it doesn't exist
	db.query("""
		CREATE TABLE IF NOT EXISTS user_puzzle_history (
			puzzle_id TEXT PRIMARY KEY,
			result TEXT NOT NULL,
			mode TEXT NOT NULL,
			attempts INTEGER DEFAULT 1,
			solved_at DATETIME,
			time_spent_ms INTEGER,
			rating INTEGER DEFAULT 0
		);
	""")

	# Create index for faster queries
	db.query("CREATE INDEX IF NOT EXISTS idx_history_result ON user_puzzle_history(result);")
	db.query("CREATE INDEX IF NOT EXISTS idx_history_mode ON user_puzzle_history(mode);")


## Save a puzzle result to history and update stats.
func save_puzzle_result(puzzle_id: String, result: String, mode: String, attempts: int, time_ms: int, rating: int = 0) -> void:
	var now = Time.get_datetime_string_from_system()

	db.query_with_bindings("""
		INSERT OR REPLACE INTO user_puzzle_history
		(puzzle_id, result, mode, attempts, solved_at, time_spent_ms, rating)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	""", [puzzle_id, result, mode, attempts, now, time_ms, rating])

	_update_aggregate_stats(mode, result, time_ms)


## Get puzzle history for a specific puzzle.
func get_puzzle_history(puzzle_id: String) -> Dictionary:
	db.query_with_bindings("SELECT * FROM user_puzzle_history WHERE puzzle_id = ?", [puzzle_id])
	return db.query_result[0] if db.query_result.size() > 0 else {}


## Check if a puzzle has been solved.
func is_puzzle_solved(puzzle_id: String) -> bool:
	db.query_with_bindings("SELECT result FROM user_puzzle_history WHERE puzzle_id = ? AND result = 'solved'", [puzzle_id])
	return db.query_result.size() > 0


## Get accuracy by rating range.
func get_accuracy_by_rating_range() -> Dictionary:
	var ranges = [[800, 1000], [1000, 1200], [1200, 1400], [1400, 1600], [1600, 1800], [1800, 2000], [2000, 2200], [2200, 2500]]
	var result: Dictionary = {}

	for r in ranges:
		var key = "%d-%d" % [r[0], r[1]]
		db.query_with_bindings("""
			SELECT
				COUNT(CASE WHEN result = 'solved' THEN 1 END) as solved,
				COUNT(*) as total
			FROM user_puzzle_history
			WHERE rating >= ? AND rating < ?
		""", [r[0], r[1]])

		if db.query_result.size() > 0:
			var row = db.query_result[0]
			var total = row.get("total", 0)
			if total > 0:
				result[key] = float(row.get("solved", 0)) / float(total)
			else:
				result[key] = 0.0

	return result


## Get solve count by mate depth.
func get_solve_count_by_mate_depth() -> Dictionary:
	var result: Dictionary = {}

	for depth in range(1, 6):
		db.query_with_bindings("""
			SELECT COUNT(*) as count
			FROM user_puzzle_history h
			WHERE h.result = 'solved'
			AND EXISTS (
				SELECT 1 FROM puzzles p WHERE p.id = h.puzzle_id AND p.mate_in = ?
			)
		""", [depth])

		if db.query_result.size() > 0:
			result["mate_in_%d" % depth] = db.query_result[0].get("count", 0)
		else:
			result["mate_in_%d" % depth] = 0

	return result


## Get a random unsolved puzzle with optional filters.
func get_random_unsolved_puzzle(filters: Dictionary = {}) -> String:
	var query = """
		SELECT p.id
		FROM puzzles p
		LEFT JOIN user_puzzle_history h ON p.id = h.puzzle_id
		WHERE (h.puzzle_id IS NULL OR h.result != 'solved')
	"""
	var params: Array = []

	# Apply optional filters
	if filters.has("min_rating"):
		query += " AND p.rating >= ?"
		params.append(filters.min_rating)
	if filters.has("max_rating"):
		query += " AND p.rating <= ?"
		params.append(filters.max_rating)
	if filters.has("mate_in") and filters.mate_in > 0:
		query += " AND p.mate_in = ?"
		params.append(filters.mate_in)
	if filters.has("themes") and filters.themes is Array and filters.themes.size() > 0:
		var theme_conditions: Array[String] = []
		for theme in filters.themes:
			theme_conditions.append("p.themes LIKE ?")
			params.append("%" + str(theme) + "%")
		query += " AND (" + " OR ".join(theme_conditions) + ")"

	query += " ORDER BY RANDOM() LIMIT 1"

	db.query_with_bindings(query, params)
	if db.query_result.size() > 0:
		return str(db.query_result[0].id)

	# Fallback: return any puzzle matching filters if all solved
	return _get_any_puzzle_with_filters(filters)


## Fallback query when all puzzles are solved.
func _get_any_puzzle_with_filters(filters: Dictionary) -> String:
	var query = "SELECT id FROM puzzles WHERE 1=1"
	var params: Array = []

	if filters.has("min_rating"):
		query += " AND rating >= ?"
		params.append(filters.min_rating)
	if filters.has("max_rating"):
		query += " AND rating <= ?"
		params.append(filters.max_rating)
	if filters.has("mate_in") and filters.mate_in > 0:
		query += " AND mate_in = ?"
		params.append(filters.mate_in)

	query += " ORDER BY RANDOM() LIMIT 1"

	db.query_with_bindings(query, params)
	if db.query_result.size() > 0:
		return str(db.query_result[0].id)

	return ""


## Update aggregate statistics.
func _update_aggregate_stats(mode: String, result: String, time_ms: int) -> void:
	stats["total_time_played_ms"] += time_ms

	if result == "solved":
		stats["total_puzzles_solved"] += 1
	else:
		stats["total_puzzles_failed"] += 1

	if stats.has(mode):
		stats[mode]["time_ms"] = stats[mode].get("time_ms", 0) + time_ms
		if result == "solved":
			stats[mode]["solved"] = stats[mode].get("solved", 0) + 1
		else:
			stats[mode]["failed"] = stats[mode].get("failed", 0) + 1

	_save_stats()
	stats_updated.emit()


## Get stats for a specific mode.
func get_stats_for_mode(mode: String) -> Dictionary:
	return stats.get(mode, {})


## Get overall stats.
func get_overall_stats() -> Dictionary:
	var total = stats.total_puzzles_solved + stats.total_puzzles_failed
	var accuracy = 0.0
	if total > 0:
		accuracy = float(stats.total_puzzles_solved) / float(total) * 100.0

	return {
		"total_puzzles": total,
		"total_solved": stats.total_puzzles_solved,
		"accuracy": accuracy,
		"time_played_hours": float(stats.total_time_played_ms) / 3600000.0,
		"player_rating": stats.player_rating
	}


## Update sprint best score.
func update_sprint_best(time_limit: float, puzzles_solved: int) -> bool:
	var key = ""
	if time_limit == 60.0:
		key = "best_1min"
	elif time_limit == 180.0:
		key = "best_3min"
	elif time_limit == 300.0:
		key = "best_5min"
	else:
		return false

	var current_best = stats.sprint.get(key, 0)
	if puzzles_solved > current_best:
		stats.sprint[key] = puzzles_solved
		stats.sprint.games_played = stats.sprint.get("games_played", 0) + 1
		_save_stats()
		return true

	stats.sprint.games_played = stats.sprint.get("games_played", 0) + 1
	_save_stats()
	return false


## Update streak best.
func update_streak_best(streak: int, peak_rating: int) -> bool:
	var is_new_best = false

	if streak > stats.streak.get("best_streak", 0):
		stats.streak.best_streak = streak
		is_new_best = true

	if peak_rating > stats.streak.get("best_peak_rating", 0):
		stats.streak.best_peak_rating = peak_rating

	stats.streak.games_played = stats.streak.get("games_played", 0) + 1
	stats.streak.total_puzzles = stats.streak.get("total_puzzles", 0) + streak

	_save_stats()
	return is_new_best


## Check if daily is completed today.
func is_daily_completed_today() -> bool:
	var today = Time.get_date_string_from_system()
	return stats.daily.get("last_completed", "") == today


## Load stats from JSON file.
func _load_stats() -> void:
	if not FileAccess.file_exists(STATS_PATH):
		return

	var file = FileAccess.open(STATS_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var loaded = json.data
			if loaded is Dictionary:
				# Merge with defaults to handle new fields
				_merge_dict(stats, loaded)
		file.close()


## Save stats to JSON file.
func _save_stats() -> void:
	var file = FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(stats, "  "))
		file.close()


## Load settings from JSON file.
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var loaded = json.data
			if loaded is Dictionary:
				for key in loaded:
					if settings.has(key) and _validate_setting(key, loaded[key]):
						settings[key] = loaded[key]
		file.close()


## Save settings to JSON file.
func _save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "  "))
		file.close()


## Update a setting with validation.
func update_setting(key: String, value: Variant) -> bool:
	if not _validate_setting(key, value):
		push_warning("Invalid setting: %s = %s" % [key, str(value)])
		return false

	settings[key] = value
	_save_settings()
	settings_updated.emit(key, value)
	return true


## Get a setting value.
func get_setting(key: String, default: Variant = null) -> Variant:
	return settings.get(key, default)


## Validate a setting value.
func _validate_setting(key: String, value: Variant) -> bool:
	match key:
		"sound_enabled", "music_enabled", "show_legal_moves", "auto_flip_board", "auto_promote_queen":
			return typeof(value) == TYPE_BOOL
		"animation_speed":
			return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and value >= 0.1 and value <= 3.0
		"theme":
			return typeof(value) == TYPE_STRING
	return true


## Recursively merge dictionaries, preserving nested structure.
func _merge_dict(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if target.has(key) and target[key] is Dictionary and source[key] is Dictionary:
			_merge_dict(target[key], source[key])
		else:
			target[key] = source[key]


## Reset all user data (for debugging/testing).
func reset_all_data() -> void:
	# Clear database
	db.query("DELETE FROM user_puzzle_history;")

	# Reset stats to defaults
	stats = {
		"player_rating": 1200,
		"total_puzzles_solved": 0,
		"total_puzzles_failed": 0,
		"total_time_played_ms": 0,
		"practice": {"solved": 0, "failed": 0, "time_ms": 0, "hints_used": 0},
		"sprint": {"best_1min": 0, "best_3min": 0, "best_5min": 0, "games_played": 0, "puzzles_solved": 0},
		"streak": {"best_streak": 0, "best_peak_rating": 0, "games_played": 0, "total_puzzles": 0},
		"daily": {"days_played": 0, "current_streak": 0, "best_streak": 0, "perfect_days": 0, "last_completed": ""}
	}
	_save_stats()
	stats_updated.emit()
