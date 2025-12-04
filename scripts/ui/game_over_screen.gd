class_name GameOverScreen
extends Control
## Game over screen with mode-specific layouts and statistics.

signal main_menu_requested()
signal play_again_requested(mode: String)
signal replay_last_requested()
signal share_requested()

# Mode that just ended
var current_mode: String = ""
var game_stats: Dictionary = {}

# Common UI
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var stats_container: VBoxContainer = $VBoxContainer/StatsContainer
@onready var new_best_label: Label = $VBoxContainer/NewBestLabel
@onready var button_container: VBoxContainer = $VBoxContainer/ButtonContainer

@onready var play_again_btn: Button = $VBoxContainer/ButtonContainer/PlayAgainButton
@onready var replay_btn: Button = $VBoxContainer/ButtonContainer/ReplayButton
@onready var menu_btn: Button = $VBoxContainer/ButtonContainer/MenuButton

# Sprint-specific
@onready var sprint_layout: Control = $VBoxContainer/StatsContainer/SprintLayout
@onready var sprint_solved_label: Label = $VBoxContainer/StatsContainer/SprintLayout/SolvedLabel
@onready var sprint_accuracy_label: Label = $VBoxContainer/StatsContainer/SprintLayout/AccuracyLabel
@onready var sprint_strikes_label: Label = $VBoxContainer/StatsContainer/SprintLayout/StrikesLabel
@onready var sprint_time_label: Label = $VBoxContainer/StatsContainer/SprintLayout/TimeLabel

# Streak-specific
@onready var streak_layout: Control = $VBoxContainer/StatsContainer/StreakLayout
@onready var streak_count_label: Label = $VBoxContainer/StatsContainer/StreakLayout/StreakLabel
@onready var streak_rating_label: Label = $VBoxContainer/StatsContainer/StreakLayout/RatingLabel
@onready var replay_puzzle_btn: Button = $VBoxContainer/ButtonContainer/ReplayPuzzleButton

# Daily-specific (use existing daily_complete scene logic)
@onready var daily_layout: Control = $VBoxContainer/StatsContainer/DailyLayout
@onready var daily_grid_label: Label = $VBoxContainer/StatsContainer/DailyLayout/EmojiGridLabel
@onready var daily_score_label: Label = $VBoxContainer/StatsContainer/DailyLayout/ScoreLabel
@onready var daily_streak_label: Label = $VBoxContainer/StatsContainer/DailyLayout/StreakLabel
@onready var share_btn: Button = $VBoxContainer/ButtonContainer/ShareButton
@onready var copied_label: Label = $VBoxContainer/CopiedLabel

var share_text: String = ""


func _ready() -> void:
	_connect_signals()
	_hide_all_layouts()
	if new_best_label:
		new_best_label.visible = false
	if copied_label:
		copied_label.visible = false


func _connect_signals() -> void:
	if play_again_btn:
		play_again_btn.pressed.connect(_on_play_again_pressed)
	if replay_btn:
		replay_btn.pressed.connect(_on_replay_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	if share_btn:
		share_btn.pressed.connect(_on_share_pressed)
	if replay_puzzle_btn:
		replay_puzzle_btn.pressed.connect(_on_replay_puzzle_pressed)


func _hide_all_layouts() -> void:
	if sprint_layout:
		sprint_layout.visible = false
	if streak_layout:
		streak_layout.visible = false
	if daily_layout:
		daily_layout.visible = false
	if share_btn:
		share_btn.visible = false
	if replay_puzzle_btn:
		replay_puzzle_btn.visible = false


## Show results for the specified mode.
func show_results(mode: String, stats: Dictionary) -> void:
	current_mode = mode
	game_stats = stats
	visible = true

	_hide_all_layouts()

	match mode:
		"sprint":
			_show_sprint_results(stats)
		"streak":
			_show_streak_results(stats)
		"daily":
			_show_daily_results(stats)


func _show_sprint_results(stats: Dictionary) -> void:
	var reason = stats.get("reason", "time")

	if reason == "time":
		title_label.text = "TIME'S UP!"
	elif reason == "strikes":
		title_label.text = "STRUCK OUT!"
	else:
		title_label.text = "GAME OVER"

	if sprint_layout:
		sprint_layout.visible = true

	var puzzles_solved = stats.get("puzzles_solved", 0)
	var attempts = stats.get("attempts", 0)
	var strikes = stats.get("strikes", 0)
	var time_remaining = stats.get("time_remaining", 0.0)
	var is_new_best = stats.get("is_new_best", false)

	if sprint_solved_label:
		sprint_solved_label.text = "Puzzles Solved: %d" % puzzles_solved

	if sprint_accuracy_label:
		var accuracy = 0.0
		if attempts > 0:
			accuracy = float(puzzles_solved) / float(attempts) * 100.0
		sprint_accuracy_label.text = "Accuracy: %.0f%%" % accuracy

	if sprint_strikes_label:
		sprint_strikes_label.text = "Strikes: %d / 3" % strikes

	if sprint_time_label:
		var total_seconds = int(max(0, time_remaining))
		var minutes = total_seconds / 60
		var secs = total_seconds % 60
		sprint_time_label.text = "Time Remaining: %d:%02d" % [minutes, secs]

	if is_new_best and new_best_label:
		new_best_label.text = "NEW BEST!"
		new_best_label.visible = true


func _show_streak_results(stats: Dictionary) -> void:
	title_label.text = "STREAK ENDED"

	if streak_layout:
		streak_layout.visible = true
	if replay_puzzle_btn:
		replay_puzzle_btn.visible = true

	var final_streak = stats.get("streak", 0)
	var start_rating = stats.get("start_rating", 1200)
	var peak_rating = stats.get("peak_rating", 1200)
	var is_new_best = stats.get("is_new_best", false)

	if streak_count_label:
		streak_count_label.text = "Final Streak: %d" % final_streak

	if streak_rating_label:
		streak_rating_label.text = "Rating: %d → %d" % [start_rating, peak_rating]

	if is_new_best and new_best_label:
		new_best_label.text = "NEW RECORD!"
		new_best_label.visible = true


func _show_daily_results(stats: Dictionary) -> void:
	var results = stats.get("results", [])
	var score = stats.get("score", 0.0)
	var streak = stats.get("streak", 0)
	share_text = stats.get("share_text", "")

	# Count solved
	var solved_count = 0
	for result in results:
		if result.get("solved", false):
			solved_count += 1

	# Set title based on performance
	if solved_count == 5:
		title_label.text = "PERFECT DAY!"
	elif solved_count >= 3:
		title_label.text = "DAILY COMPLETE!"
	else:
		title_label.text = "DAILY FINISHED"

	if daily_layout:
		daily_layout.visible = true
	if share_btn:
		share_btn.visible = true

	# Build emoji grid
	var emoji_grid = ""
	for result in results:
		emoji_grid += "🟩" if result.get("solved", false) else "⬛"

	if daily_grid_label:
		daily_grid_label.text = emoji_grid

	if daily_score_label:
		var max_score = 5.0 + 2.5  # 5 puzzles + 5 perfect bonuses
		daily_score_label.text = "Score: %.1f / %.1f" % [score, max_score]

	if daily_streak_label:
		if streak > 1:
			daily_streak_label.text = "🔥 Streak: %d days" % streak
			daily_streak_label.visible = true
		else:
			daily_streak_label.visible = false


func _on_play_again_pressed() -> void:
	play_again_requested.emit(current_mode)


func _on_replay_pressed() -> void:
	replay_last_requested.emit()


func _on_menu_pressed() -> void:
	main_menu_requested.emit()


func _on_share_pressed() -> void:
	if not share_text.is_empty():
		DisplayServer.clipboard_set(share_text)

		if copied_label:
			copied_label.visible = true
			await get_tree().create_timer(2.0).timeout
			if copied_label:
				copied_label.visible = false


func _on_replay_puzzle_pressed() -> void:
	replay_last_requested.emit()
