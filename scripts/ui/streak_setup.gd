class_name StreakSetup
extends Control
## Streak mode setup screen for selecting starting difficulty.

## Emitted when user clicks start with configured settings
signal start_requested(settings: Dictionary)

## Emitted when user wants to go back
signal back_requested()

# UI element references
@onready var beginner_btn: Button = $VBoxContainer/DifficultySection/DifficultyButtons/BeginnerButton
@onready var intermediate_btn: Button = $VBoxContainer/DifficultySection/DifficultyButtons/IntermediateButton
@onready var advanced_btn: Button = $VBoxContainer/DifficultySection/DifficultyButtons/AdvancedButton
@onready var expert_btn: Button = $VBoxContainer/DifficultySection/DifficultyButtons/ExpertButton
@onready var custom_btn: Button = $VBoxContainer/DifficultySection/DifficultyButtons/CustomButton

@onready var custom_section: HBoxContainer = $VBoxContainer/CustomSection
@onready var custom_slider: HSlider = $VBoxContainer/CustomSection/CustomSlider
@onready var custom_value_label: Label = $VBoxContainer/CustomSection/CustomValueLabel

@onready var best_streak_label: Label = $VBoxContainer/BestStreakLabel
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var back_button: Button = $VBoxContainer/BackButton

# Stats file
const STATS_FILE = "user://streak_stats.json"

# Selected difficulty
var selected_difficulty: String = "intermediate"
var custom_rating: int = 1200

# Best streaks per difficulty
var best_streaks: Dictionary = {}


func _ready() -> void:
	_load_best_streaks()
	_setup_difficulty_buttons()
	_setup_custom_section()
	_connect_signals()
	_update_best_streak_display()


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


func _setup_difficulty_buttons() -> void:
	# Default: Intermediate selected
	intermediate_btn.button_pressed = true


func _setup_custom_section() -> void:
	custom_section.visible = false
	custom_slider.min_value = 400
	custom_slider.max_value = 2400
	custom_slider.step = 50
	custom_slider.value = 1200
	custom_value_label.text = "1200"


func _connect_signals() -> void:
	beginner_btn.pressed.connect(_on_beginner_pressed)
	intermediate_btn.pressed.connect(_on_intermediate_pressed)
	advanced_btn.pressed.connect(_on_advanced_pressed)
	expert_btn.pressed.connect(_on_expert_pressed)
	custom_btn.pressed.connect(_on_custom_pressed)

	custom_slider.value_changed.connect(_on_custom_slider_changed)

	start_button.pressed.connect(_on_start_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _select_difficulty_button(btn: Button) -> void:
	beginner_btn.button_pressed = (btn == beginner_btn)
	intermediate_btn.button_pressed = (btn == intermediate_btn)
	advanced_btn.button_pressed = (btn == advanced_btn)
	expert_btn.button_pressed = (btn == expert_btn)
	custom_btn.button_pressed = (btn == custom_btn)

	custom_section.visible = (btn == custom_btn)
	_update_best_streak_display()


func _on_beginner_pressed() -> void:
	selected_difficulty = "beginner"
	_select_difficulty_button(beginner_btn)


func _on_intermediate_pressed() -> void:
	selected_difficulty = "intermediate"
	_select_difficulty_button(intermediate_btn)


func _on_advanced_pressed() -> void:
	selected_difficulty = "advanced"
	_select_difficulty_button(advanced_btn)


func _on_expert_pressed() -> void:
	selected_difficulty = "expert"
	_select_difficulty_button(expert_btn)


func _on_custom_pressed() -> void:
	selected_difficulty = "custom"
	_select_difficulty_button(custom_btn)


func _on_custom_slider_changed(value: float) -> void:
	custom_rating = int(value)
	custom_value_label.text = str(custom_rating)
	_update_best_streak_display()


func _update_best_streak_display() -> void:
	var key = _get_stats_key()
	var best = best_streaks.get(key, {})
	var best_streak = best.get("streak", 0)

	if best_streak > 0:
		var peak = best.get("peak_rating", 0)
		best_streak_label.text = "Best: %d streak (peak: %d)" % [best_streak, peak]
	else:
		best_streak_label.text = "No record yet"


func _get_stats_key() -> String:
	if selected_difficulty == "custom":
		return "custom_%d" % custom_rating
	return selected_difficulty


func _on_start_pressed() -> void:
	var settings = get_settings()
	start_requested.emit(settings)


func _on_back_pressed() -> void:
	back_requested.emit()


## Get the current settings as a Dictionary.
func get_settings() -> Dictionary:
	var settings = {
		"difficulty": selected_difficulty
	}

	if selected_difficulty == "custom":
		settings["start_rating"] = custom_rating

	return settings


## Save a new best streak.
func save_best_streak(streak: int, peak_rating: int) -> void:
	var key = _get_stats_key()
	var current_best = best_streaks.get(key, {}).get("streak", 0)

	if streak > current_best:
		best_streaks[key] = {
			"streak": streak,
			"peak_rating": peak_rating,
			"date": Time.get_datetime_string_from_system()
		}
		_save_best_streaks()


func _save_best_streaks() -> void:
	var file = FileAccess.open(STATS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(best_streaks))
		file.close()
