class_name StreakGameOver
extends Control
## Streak mode game over screen showing stats and failed puzzle.

## Emitted when user wants to play again
signal play_again_requested()

## Emitted when user wants to go to main menu
signal main_menu_requested()

## Emitted when user wants to see the solution
signal show_solution_requested(puzzle: PuzzleData)

# UI element references
@onready var streak_label: Label = $VBoxContainer/StreakLabel
@onready var rating_progress_label: Label = $VBoxContainer/RatingProgressLabel
@onready var record_label: Label = $VBoxContainer/RecordLabel
@onready var show_solution_btn: Button = $VBoxContainer/ButtonContainer/ShowSolutionButton
@onready var play_again_btn: Button = $VBoxContainer/ButtonContainer/PlayAgainButton
@onready var menu_btn: Button = $VBoxContainer/ButtonContainer/MenuButton

# Stats file (shared with streak_setup)
const STATS_FILE = "user://streak_stats.json"

var final_stats: Dictionary = {}
var best_streaks: Dictionary = {}


func _ready() -> void:
	_load_best_streaks()
	_connect_signals()


func _connect_signals() -> void:
	show_solution_btn.pressed.connect(_on_show_solution_pressed)
	play_again_btn.pressed.connect(_on_play_again_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)


func _load_best_streaks() -> void:
	if not FileAccess.file_exists(STATS_FILE):
		best_streaks = {}
		return

	var file = FileAccess.open(STATS_FILE, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			best_streaks = json.data if json.data is Dictionary else {}
		file.close()


## Display results for completed streak run.
func show_results(stats: Dictionary) -> void:
	final_stats = stats
	visible = true

	var streak = stats.get("streak_count", 0)
	var start_rating = stats.get("start_rating", 0)
	var peak_rating = stats.get("peak_rating", 0)
	var failed_puzzle = stats.get("failed_puzzle")

	# Display streak count
	streak_label.text = "Streak: %d" % streak

	# Display rating progression
	if peak_rating > 0:
		rating_progress_label.text = "%d → %d" % [start_rating, peak_rating]
	else:
		rating_progress_label.text = "Starting: %d" % start_rating

	# Check for new record
	_check_and_display_record(stats)

	# Enable/disable solution button based on whether we have a failed puzzle
	show_solution_btn.disabled = (failed_puzzle == null)


## Check if this is a new record and display appropriately.
func _check_and_display_record(stats: Dictionary) -> void:
	var streak = stats.get("streak_count", 0)
	var start_rating = stats.get("start_rating", 0)
	var peak_rating = stats.get("peak_rating", 0)

	# Determine key based on starting difficulty
	var key = _get_stats_key_for_rating(start_rating)
	var best = best_streaks.get(key, {})
	var previous_best = best.get("streak", 0)

	if streak > previous_best:
		record_label.text = "🏆 New Record!"
		record_label.modulate = Color.GOLD

		# Save new record
		best_streaks[key] = {
			"streak": streak,
			"peak_rating": peak_rating,
			"date": Time.get_datetime_string_from_system()
		}
		_save_best_streaks()
	elif previous_best > 0:
		record_label.text = "Best: %d" % previous_best
		record_label.modulate = Color.WHITE
	else:
		record_label.text = ""


func _get_stats_key_for_rating(rating: int) -> String:
	# Map rating to difficulty key
	if rating == StreakMode.DIFFICULTY_BEGINNER:
		return "beginner"
	elif rating == StreakMode.DIFFICULTY_INTERMEDIATE:
		return "intermediate"
	elif rating == StreakMode.DIFFICULTY_ADVANCED:
		return "advanced"
	elif rating == StreakMode.DIFFICULTY_EXPERT:
		return "expert"
	else:
		return "custom_%d" % rating


func _save_best_streaks() -> void:
	var file = FileAccess.open(STATS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(best_streaks))
		file.close()


func _on_show_solution_pressed() -> void:
	var failed_puzzle = final_stats.get("failed_puzzle")
	if failed_puzzle:
		show_solution_requested.emit(failed_puzzle)


func _on_play_again_pressed() -> void:
	play_again_requested.emit()


func _on_menu_pressed() -> void:
	main_menu_requested.emit()
