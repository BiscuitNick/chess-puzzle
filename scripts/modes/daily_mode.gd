class_name DailyMode
extends Node
## Daily challenge mode with deterministic puzzles and one-attempt-per-puzzle.

## Emitted when a puzzle is completed (solved or failed)
signal puzzle_completed(index: int, solved: bool, perfect: bool)

## Emitted when all 5 puzzles are done
signal daily_completed(results: Array, score: float, streak: int)

## Emitted when daily is already completed today
signal already_completed_today()

## Emitted when advancing to next puzzle
signal next_puzzle_started(index: int, total: int)

# State
var current_puzzle_index: int = 0
var puzzle_results: Array[Dictionary] = []  # {solved: bool, perfect: bool}
var daily_puzzles: Array[PuzzleData] = []
var is_running: bool = false

# Move tracking for perfect bonus
var is_first_move: bool = true
var had_wrong_move: bool = false

# Features disabled in daily mode
var hints_enabled: bool = false
var solution_enabled: bool = false
var skip_enabled: bool = false

# Persistence
const STATS_FILE = "user://daily_stats.json"
var daily_stats: Dictionary = {}

# References
var puzzle_controller: PuzzleController
var daily_generator: DailyGenerator
var db: SQLite


func _ready() -> void:
	_load_daily_stats()


## Initialize with references.
func initialize(controller: PuzzleController, database: SQLite) -> void:
	puzzle_controller = controller
	db = database
	daily_generator = DailyGenerator.new(database)

	puzzle_controller.move_made.connect(_on_move_made)
	puzzle_controller.puzzle_completed.connect(_on_puzzle_completed)


## Check if today's daily is already completed.
func is_daily_completed_today() -> bool:
	var today = DailyGenerator.get_date_string()
	return daily_stats.get("last_completed_date", "") == today


## Get today's results if completed.
func get_today_results() -> Dictionary:
	if is_daily_completed_today():
		return {
			"results": daily_stats.get("today_results", []),
			"score": daily_stats.get("today_score", 0.0),
			"streak": daily_stats.get("current_streak", 0)
		}
	return {}


## Start the daily challenge.
func start_daily() -> void:
	if is_daily_completed_today():
		already_completed_today.emit()
		return

	# Check for day change / streak reset
	_check_daily_reset()

	# Get today's puzzles
	daily_puzzles = daily_generator.get_daily_puzzles()

	if daily_puzzles.is_empty():
		push_error("Failed to load daily puzzles")
		return

	# Reset state
	current_puzzle_index = 0
	puzzle_results.clear()
	is_running = true
	is_first_move = true
	had_wrong_move = false

	# Set puzzle controller mode
	puzzle_controller.set_mode(PuzzleController.GameMode.DAILY)

	# Load first puzzle
	_load_current_puzzle()


## Load the current puzzle.
func _load_current_puzzle() -> void:
	if current_puzzle_index >= daily_puzzles.size():
		_finish_daily()
		return

	is_first_move = true
	had_wrong_move = false

	next_puzzle_started.emit(current_puzzle_index, daily_puzzles.size())
	puzzle_controller.load_puzzle(daily_puzzles[current_puzzle_index])


## Handle move result.
func _on_move_made(_from: int, _to: int, is_correct: bool) -> void:
	if not is_running:
		return

	if is_first_move:
		is_first_move = false
		if not is_correct:
			# First move wrong - puzzle immediately failed
			_record_puzzle_result(false, false)
			return

	if not is_correct:
		had_wrong_move = true


## Handle puzzle completion from controller.
func _on_puzzle_completed(success: bool, _attempts: int) -> void:
	if not is_running:
		return

	if success:
		var perfect = not had_wrong_move
		_record_puzzle_result(true, perfect)


## Record result and advance.
func _record_puzzle_result(solved: bool, perfect: bool) -> void:
	puzzle_results.append({"solved": solved, "perfect": perfect})
	puzzle_completed.emit(current_puzzle_index, solved, perfect)

	# Advance to next puzzle
	current_puzzle_index += 1

	# Brief delay before next puzzle
	await get_tree().create_timer(1.0).timeout

	if current_puzzle_index >= daily_puzzles.size():
		_finish_daily()
	else:
		_load_current_puzzle()


## Finish the daily challenge.
func _finish_daily() -> void:
	is_running = false

	var score = _calculate_score()
	var streak = _update_streak()

	_save_daily_completion(score)

	daily_completed.emit(puzzle_results, score, streak)


## Calculate final score.
## 1 point per solved puzzle + 0.5 bonus for perfect solve
func _calculate_score() -> float:
	var score = 0.0
	for result in puzzle_results:
		if result.solved:
			score += 1.0
			if result.perfect:
				score += 0.5
	return score


## Update streak and return current value.
func _update_streak() -> int:
	var today = DailyGenerator.get_date_string()
	var yesterday = _get_yesterday_string()

	var last_date = daily_stats.get("last_completed_date", "")

	if last_date == yesterday:
		# Consecutive day - increment streak
		daily_stats["current_streak"] = daily_stats.get("current_streak", 0) + 1
	else:
		# Not consecutive - reset to 1
		daily_stats["current_streak"] = 1

	# Update best streak
	var current = daily_stats.get("current_streak", 1)
	var best = daily_stats.get("best_streak", 0)
	if current > best:
		daily_stats["best_streak"] = current

	return daily_stats["current_streak"]


## Get yesterday's date string.
func _get_yesterday_string() -> String:
	var unix = Time.get_unix_time_from_system() - 86400  # 24 hours ago
	var date = Time.get_date_dict_from_unix_time(unix)
	return DailyGenerator.date_to_string(date)


## Check if streak should reset (missed a day).
func _check_daily_reset() -> void:
	var today = DailyGenerator.get_date_string()
	var yesterday = _get_yesterday_string()
	var last_date = daily_stats.get("last_completed_date", "")

	# If last completed is not today or yesterday, reset streak
	if last_date != today and last_date != yesterday and not last_date.is_empty():
		daily_stats["current_streak"] = 0


## Save daily completion to persistent storage.
func _save_daily_completion(score: float) -> void:
	var today = DailyGenerator.get_date_string()

	daily_stats["last_completed_date"] = today
	daily_stats["today_results"] = []
	for result in puzzle_results:
		daily_stats["today_results"].append(result.duplicate())
	daily_stats["today_score"] = score
	daily_stats["days_played"] = daily_stats.get("days_played", 0) + 1
	daily_stats["total_score"] = daily_stats.get("total_score", 0.0) + score

	# Check for perfect day (all 5 solved)
	var all_solved = true
	for result in puzzle_results:
		if not result.solved:
			all_solved = false
			break
	if all_solved:
		daily_stats["perfect_days"] = daily_stats.get("perfect_days", 0) + 1

	_save_daily_stats()


## Generate shareable results text.
func generate_share_text() -> String:
	var day_num = DailyGenerator.get_day_number()
	var solved_count = 0
	var emoji_grid = ""

	for result in puzzle_results:
		if result.solved:
			emoji_grid += "🟩"
			solved_count += 1
		else:
			emoji_grid += "⬛"

	var streak = daily_stats.get("current_streak", 0)

	var text = "Chess Puzzles Daily #%d\n%s (%d/5)" % [day_num, emoji_grid, solved_count]
	if streak > 1:
		text += "\n🔥 Streak: %d" % streak

	return text


## Copy share text to clipboard.
func copy_share_to_clipboard() -> bool:
	var text = generate_share_text()
	DisplayServer.clipboard_set(text)
	return true


## Get current stats.
func get_stats() -> Dictionary:
	return {
		"days_played": daily_stats.get("days_played", 0),
		"total_score": daily_stats.get("total_score", 0.0),
		"current_streak": daily_stats.get("current_streak", 0),
		"best_streak": daily_stats.get("best_streak", 0),
		"perfect_days": daily_stats.get("perfect_days", 0)
	}


## Load daily stats from file.
func _load_daily_stats() -> void:
	if not FileAccess.file_exists(STATS_FILE):
		daily_stats = {}
		return

	var file = FileAccess.open(STATS_FILE, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			daily_stats = json.data if json.data is Dictionary else {}
		file.close()


## Save daily stats to file.
func _save_daily_stats() -> void:
	var file = FileAccess.open(STATS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(daily_stats))
		file.close()
