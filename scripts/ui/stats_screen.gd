class_name StatsScreen
extends Control
## Statistics screen showing per-mode and overall stats.

signal back_requested()

# Tab buttons
@onready var overall_tab_btn: Button = $VBoxContainer/TabBar/OverallTab
@onready var practice_tab_btn: Button = $VBoxContainer/TabBar/PracticeTab
@onready var sprint_tab_btn: Button = $VBoxContainer/TabBar/SprintTab
@onready var streak_tab_btn: Button = $VBoxContainer/TabBar/StreakTab
@onready var daily_tab_btn: Button = $VBoxContainer/TabBar/DailyTab

# Tab containers
@onready var overall_panel: Control = $VBoxContainer/TabContent/OverallPanel
@onready var practice_panel: Control = $VBoxContainer/TabContent/PracticePanel
@onready var sprint_panel: Control = $VBoxContainer/TabContent/SprintPanel
@onready var streak_panel: Control = $VBoxContainer/TabContent/StreakPanel
@onready var daily_panel: Control = $VBoxContainer/TabContent/DailyPanel

# Overall stats labels
@onready var database_puzzles_label: Label = $VBoxContainer/TabContent/OverallPanel/DatabasePuzzlesLabel
@onready var total_puzzles_label: Label = $VBoxContainer/TabContent/OverallPanel/TotalPuzzlesLabel
@onready var total_solved_label: Label = $VBoxContainer/TabContent/OverallPanel/TotalSolvedLabel
@onready var overall_accuracy_label: Label = $VBoxContainer/TabContent/OverallPanel/AccuracyLabel
@onready var total_time_label: Label = $VBoxContainer/TabContent/OverallPanel/TimePlayedLabel
@onready var player_rating_label: Label = $VBoxContainer/TabContent/OverallPanel/RatingLabel

# Practice stats labels
@onready var practice_solved_label: Label = $VBoxContainer/TabContent/PracticePanel/SolvedLabel
@onready var practice_failed_label: Label = $VBoxContainer/TabContent/PracticePanel/FailedLabel
@onready var practice_hints_label: Label = $VBoxContainer/TabContent/PracticePanel/HintsLabel
@onready var practice_time_label: Label = $VBoxContainer/TabContent/PracticePanel/TimeLabel

# Sprint stats labels
@onready var sprint_best1_label: Label = $VBoxContainer/TabContent/SprintPanel/Best1MinLabel
@onready var sprint_best3_label: Label = $VBoxContainer/TabContent/SprintPanel/Best3MinLabel
@onready var sprint_best5_label: Label = $VBoxContainer/TabContent/SprintPanel/Best5MinLabel
@onready var sprint_games_label: Label = $VBoxContainer/TabContent/SprintPanel/GamesLabel

# Streak stats labels
@onready var streak_best_label: Label = $VBoxContainer/TabContent/StreakPanel/BestStreakLabel
@onready var streak_peak_label: Label = $VBoxContainer/TabContent/StreakPanel/PeakRatingLabel
@onready var streak_games_label: Label = $VBoxContainer/TabContent/StreakPanel/GamesLabel
@onready var streak_total_label: Label = $VBoxContainer/TabContent/StreakPanel/TotalPuzzlesLabel

# Daily stats labels
@onready var daily_days_label: Label = $VBoxContainer/TabContent/DailyPanel/DaysPlayedLabel
@onready var daily_current_label: Label = $VBoxContainer/TabContent/DailyPanel/CurrentStreakLabel
@onready var daily_best_label: Label = $VBoxContainer/TabContent/DailyPanel/BestStreakLabel
@onready var daily_perfect_label: Label = $VBoxContainer/TabContent/DailyPanel/PerfectDaysLabel

@onready var back_btn: Button = $VBoxContainer/BackButton

var current_tab: String = "overall"


func _ready() -> void:
	_connect_signals()
	_show_tab("overall")
	_load_stats()


func _connect_signals() -> void:
	if overall_tab_btn:
		overall_tab_btn.pressed.connect(func(): _show_tab("overall"))
	if practice_tab_btn:
		practice_tab_btn.pressed.connect(func(): _show_tab("practice"))
	if sprint_tab_btn:
		sprint_tab_btn.pressed.connect(func(): _show_tab("sprint"))
	if streak_tab_btn:
		streak_tab_btn.pressed.connect(func(): _show_tab("streak"))
	if daily_tab_btn:
		daily_tab_btn.pressed.connect(func(): _show_tab("daily"))
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)


func _show_tab(tab_name: String) -> void:
	current_tab = tab_name

	# Hide all panels
	if overall_panel:
		overall_panel.visible = false
	if practice_panel:
		practice_panel.visible = false
	if sprint_panel:
		sprint_panel.visible = false
	if streak_panel:
		streak_panel.visible = false
	if daily_panel:
		daily_panel.visible = false

	# Show selected panel
	match tab_name:
		"overall":
			if overall_panel:
				overall_panel.visible = true
		"practice":
			if practice_panel:
				practice_panel.visible = true
		"sprint":
			if sprint_panel:
				sprint_panel.visible = true
		"streak":
			if streak_panel:
				streak_panel.visible = true
		"daily":
			if daily_panel:
				daily_panel.visible = true

	# Update tab button states
	_update_tab_buttons(tab_name)


func _update_tab_buttons(active_tab: String) -> void:
	var tabs = {
		"overall": overall_tab_btn,
		"practice": practice_tab_btn,
		"sprint": sprint_tab_btn,
		"streak": streak_tab_btn,
		"daily": daily_tab_btn
	}

	for tab_name in tabs:
		var btn = tabs[tab_name]
		if btn:
			btn.button_pressed = (tab_name == active_tab)


func _load_stats() -> void:
	var stats = UserData.stats

	# Overall stats
	var overall = UserData.get_overall_stats()
	if database_puzzles_label:
		var db_count = UserData.get_total_puzzle_count()
		database_puzzles_label.text = "Puzzles in Database: %d" % db_count
	if total_puzzles_label:
		total_puzzles_label.text = "Total Attempted: %d" % overall.get("total_puzzles", 0)
	if total_solved_label:
		total_solved_label.text = "Puzzles Solved: %d" % overall.get("total_solved", 0)
	if overall_accuracy_label:
		overall_accuracy_label.text = "Accuracy: %.1f%%" % overall.get("accuracy", 0.0)
	if total_time_label:
		var hours = overall.get("time_played_hours", 0.0)
		if hours < 1.0:
			total_time_label.text = "Time Played: %d min" % int(hours * 60)
		else:
			total_time_label.text = "Time Played: %.1f hours" % hours
	if player_rating_label:
		player_rating_label.text = "Rating: %d" % overall.get("player_rating", 1200)

	# Practice stats
	var practice = stats.get("practice", {})
	if practice_solved_label:
		practice_solved_label.text = "Solved: %d" % practice.get("solved", 0)
	if practice_failed_label:
		practice_failed_label.text = "Failed: %d" % practice.get("failed", 0)
	if practice_hints_label:
		practice_hints_label.text = "Hints Used: %d" % practice.get("hints_used", 0)
	if practice_time_label:
		var time_ms = practice.get("time_ms", 0)
		var minutes = time_ms / 60000
		practice_time_label.text = "Time: %d min" % minutes

	# Sprint stats
	var sprint = stats.get("sprint", {})
	if sprint_best1_label:
		sprint_best1_label.text = "Best 1 Min: %d" % sprint.get("best_1min", 0)
	if sprint_best3_label:
		sprint_best3_label.text = "Best 3 Min: %d" % sprint.get("best_3min", 0)
	if sprint_best5_label:
		sprint_best5_label.text = "Best 5 Min: %d" % sprint.get("best_5min", 0)
	if sprint_games_label:
		sprint_games_label.text = "Games Played: %d" % sprint.get("games_played", 0)

	# Streak stats
	var streak = stats.get("streak", {})
	if streak_best_label:
		streak_best_label.text = "Best Streak: %d" % streak.get("best_streak", 0)
	if streak_peak_label:
		streak_peak_label.text = "Peak Rating: %d" % streak.get("best_peak_rating", 0)
	if streak_games_label:
		streak_games_label.text = "Games Played: %d" % streak.get("games_played", 0)
	if streak_total_label:
		streak_total_label.text = "Total Puzzles: %d" % streak.get("total_puzzles", 0)

	# Daily stats
	var daily = stats.get("daily", {})
	if daily_days_label:
		daily_days_label.text = "Days Played: %d" % daily.get("days_played", 0)
	if daily_current_label:
		daily_current_label.text = "Current Streak: %d days" % daily.get("current_streak", 0)
	if daily_best_label:
		daily_best_label.text = "Best Streak: %d days" % daily.get("best_streak", 0)
	if daily_perfect_label:
		daily_perfect_label.text = "Perfect Days: %d" % daily.get("perfect_days", 0)


func _on_back_pressed() -> void:
	back_requested.emit()
