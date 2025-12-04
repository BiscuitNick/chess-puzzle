class_name MainMenu
extends Control
## Main menu screen with mode selection and navigation.

signal scene_change_requested(scene_name: String)
signal scene_push_requested(scene_name: String)

@onready var practice_btn: Button = $VBoxContainer/ModeButtons/PracticeButton
@onready var sprint_btn: Button = $VBoxContainer/ModeButtons/SprintButton
@onready var streak_btn: Button = $VBoxContainer/ModeButtons/StreakButton
@onready var daily_btn: Button = $VBoxContainer/ModeButtons/DailyButton
@onready var daily_status_label: Label = $VBoxContainer/ModeButtons/DailyButton/StatusLabel

@onready var stats_btn: Button = $VBoxContainer/NavButtons/StatsButton
@onready var settings_btn: Button = $VBoxContainer/NavButtons/SettingsButton
@onready var quit_btn: Button = $VBoxContainer/NavButtons/QuitButton


func _ready() -> void:
	_connect_signals()
	_update_daily_status()


func _connect_signals() -> void:
	practice_btn.pressed.connect(_on_practice_pressed)
	sprint_btn.pressed.connect(_on_sprint_pressed)
	streak_btn.pressed.connect(_on_streak_pressed)
	daily_btn.pressed.connect(_on_daily_pressed)

	stats_btn.pressed.connect(_on_stats_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)


func _update_daily_status() -> void:
	if UserData.is_daily_completed_today():
		if daily_status_label:
			daily_status_label.text = "Completed"
			daily_status_label.visible = true
	else:
		if daily_status_label:
			daily_status_label.visible = false


func _on_practice_pressed() -> void:
	scene_push_requested.emit("practice_setup")


func _on_sprint_pressed() -> void:
	scene_push_requested.emit("sprint_setup")


func _on_streak_pressed() -> void:
	scene_push_requested.emit("streak_setup")


func _on_daily_pressed() -> void:
	# Go directly to puzzle screen in daily mode
	scene_change_requested.emit("puzzle_screen")


func _on_stats_pressed() -> void:
	scene_push_requested.emit("stats_screen")


func _on_settings_pressed() -> void:
	scene_push_requested.emit("settings_menu")


func _on_quit_pressed() -> void:
	get_tree().quit()
