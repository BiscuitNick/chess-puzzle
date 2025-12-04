class_name SprintResults
extends Control
## Sprint mode results screen showing final stats.

## Emitted when user wants to play again
signal play_again_requested()

## Emitted when user wants to change settings
signal change_settings_requested()

## Emitted when user wants to go to main menu
signal main_menu_requested()

# UI element references
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var puzzles_solved_label: Label = $VBoxContainer/StatsContainer/PuzzlesSolvedLabel
@onready var accuracy_label: Label = $VBoxContainer/StatsContainer/AccuracyLabel
@onready var strikes_label: Label = $VBoxContainer/StatsContainer/StrikesLabel
@onready var time_label: Label = $VBoxContainer/StatsContainer/TimeLabel
@onready var best_score_label: Label = $VBoxContainer/BestScoreLabel

@onready var play_again_btn: Button = $VBoxContainer/ButtonContainer/PlayAgainButton
@onready var settings_btn: Button = $VBoxContainer/ButtonContainer/SettingsButton
@onready var menu_btn: Button = $VBoxContainer/ButtonContainer/MenuButton

# Stats storage key format: "sprint_{time_limit}_{difficulty}"
const STATS_FILE = "user://sprint_best_scores.json"

var current_stats: Dictionary = {}
var best_scores: Dictionary = {}


func _ready() -> void:
	_load_best_scores()
	_connect_signals()


func _connect_signals() -> void:
	play_again_btn.pressed.connect(_on_play_again_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)


## Display results for completed game.
func show_results(stats: Dictionary) -> void:
	current_stats = stats
	visible = true

	# Update title based on end reason
	var reason = stats.get("reason", "")
	match reason:
		"time":
			title_label.text = "Time's Up!"
		"strikes":
			title_label.text = "Three Strikes!"
		_:
			title_label.text = "Game Over"

	# Update stats display
	puzzles_solved_label.text = "Puzzles Solved: %d" % stats.get("puzzles_solved", 0)

	var accuracy = stats.get("accuracy", 0.0)
	accuracy_label.text = "Accuracy: %.1f%%" % accuracy

	strikes_label.text = "Strikes: %d / 3" % stats.get("strikes", 0)

	var time_used = stats.get("time_used", 0.0)
	time_label.text = "Time Used: %s" % SprintMode.format_time(time_used)

	# Check and update best score
	_check_best_score(stats)


## Check if this is a new best score.
func _check_best_score(stats: Dictionary) -> void:
	var time_limit = stats.get("time_limit", 180.0)
	var difficulty = stats.get("difficulty", "medium")
	var key = "sprint_%d_%s" % [int(time_limit), difficulty]

	var puzzles_solved = stats.get("puzzles_solved", 0)
	var best = best_scores.get(key, 0)

	if puzzles_solved > best:
		best_scores[key] = puzzles_solved
		_save_best_scores()
		best_score_label.text = "New Best Score!"
		best_score_label.modulate = Color.GOLD
	elif best > 0:
		best_score_label.text = "Best: %d puzzles" % best
		best_score_label.modulate = Color.WHITE
	else:
		best_score_label.text = ""


## Load best scores from file.
func _load_best_scores() -> void:
	if not FileAccess.file_exists(STATS_FILE):
		best_scores = {}
		return

	var file = FileAccess.open(STATS_FILE, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			best_scores = json.data if json.data is Dictionary else {}
		file.close()


## Save best scores to file.
func _save_best_scores() -> void:
	var file = FileAccess.open(STATS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(best_scores))
		file.close()


## Get best score for given settings.
func get_best_score(time_limit: float, difficulty: String) -> int:
	var key = "sprint_%d_%s" % [int(time_limit), difficulty]
	return best_scores.get(key, 0)


func _on_play_again_pressed() -> void:
	play_again_requested.emit()


func _on_settings_pressed() -> void:
	change_settings_requested.emit()


func _on_menu_pressed() -> void:
	main_menu_requested.emit()
