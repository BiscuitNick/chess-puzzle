class_name SprintSetup
extends Control
## Sprint mode setup screen for selecting time limit and difficulty.

## Emitted when user clicks start with configured settings
signal start_requested(settings: Dictionary)

## Emitted when user wants to go back
signal back_requested()

# UI element references
@onready var time_1min_btn: Button = $VBoxContainer/TimeSection/TimeButtons/Time1MinButton
@onready var time_3min_btn: Button = $VBoxContainer/TimeSection/TimeButtons/Time3MinButton
@onready var time_5min_btn: Button = $VBoxContainer/TimeSection/TimeButtons/Time5MinButton

@onready var easy_btn: Button = $VBoxContainer/DifficultySection/DifficultyButtons/EasyButton
@onready var medium_btn: Button = $VBoxContainer/DifficultySection/DifficultyButtons/MediumButton
@onready var hard_btn: Button = $VBoxContainer/DifficultySection/DifficultyButtons/HardButton
@onready var custom_btn: Button = $VBoxContainer/DifficultySection/DifficultyButtons/CustomButton

@onready var custom_section: VBoxContainer = $VBoxContainer/CustomRatingSection
@onready var min_rating_spinbox: SpinBox = $VBoxContainer/CustomRatingSection/MinRatingContainer/MinRatingSpinBox
@onready var max_rating_spinbox: SpinBox = $VBoxContainer/CustomRatingSection/MaxRatingContainer/MaxRatingSpinBox

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var back_button: Button = $VBoxContainer/BackButton

# Selected values
var selected_time: float = SprintMode.TIME_3_MIN
var selected_difficulty: String = "medium"


func _ready() -> void:
	_setup_time_buttons()
	_setup_difficulty_buttons()
	_setup_custom_section()
	_connect_signals()


func _setup_time_buttons() -> void:
	# Default: 3 minutes selected
	time_3min_btn.button_pressed = true


func _setup_difficulty_buttons() -> void:
	# Default: Medium selected
	medium_btn.button_pressed = true


func _setup_custom_section() -> void:
	# Hide custom section by default
	custom_section.visible = false

	min_rating_spinbox.min_value = 400
	min_rating_spinbox.max_value = 3000
	min_rating_spinbox.step = 50
	min_rating_spinbox.value = 1200

	max_rating_spinbox.min_value = 400
	max_rating_spinbox.max_value = 3000
	max_rating_spinbox.step = 50
	max_rating_spinbox.value = 1600


func _connect_signals() -> void:
	# Time buttons
	time_1min_btn.pressed.connect(_on_time_1min_pressed)
	time_3min_btn.pressed.connect(_on_time_3min_pressed)
	time_5min_btn.pressed.connect(_on_time_5min_pressed)

	# Difficulty buttons
	easy_btn.pressed.connect(_on_easy_pressed)
	medium_btn.pressed.connect(_on_medium_pressed)
	hard_btn.pressed.connect(_on_hard_pressed)
	custom_btn.pressed.connect(_on_custom_pressed)

	# Rating constraints
	min_rating_spinbox.value_changed.connect(_on_min_rating_changed)
	max_rating_spinbox.value_changed.connect(_on_max_rating_changed)

	# Main buttons
	start_button.pressed.connect(_on_start_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _select_time_button(btn: Button) -> void:
	time_1min_btn.button_pressed = (btn == time_1min_btn)
	time_3min_btn.button_pressed = (btn == time_3min_btn)
	time_5min_btn.button_pressed = (btn == time_5min_btn)


func _select_difficulty_button(btn: Button) -> void:
	easy_btn.button_pressed = (btn == easy_btn)
	medium_btn.button_pressed = (btn == medium_btn)
	hard_btn.button_pressed = (btn == hard_btn)
	custom_btn.button_pressed = (btn == custom_btn)

	# Show/hide custom section
	custom_section.visible = (btn == custom_btn)


func _on_time_1min_pressed() -> void:
	selected_time = SprintMode.TIME_1_MIN
	_select_time_button(time_1min_btn)


func _on_time_3min_pressed() -> void:
	selected_time = SprintMode.TIME_3_MIN
	_select_time_button(time_3min_btn)


func _on_time_5min_pressed() -> void:
	selected_time = SprintMode.TIME_5_MIN
	_select_time_button(time_5min_btn)


func _on_easy_pressed() -> void:
	selected_difficulty = "easy"
	_select_difficulty_button(easy_btn)


func _on_medium_pressed() -> void:
	selected_difficulty = "medium"
	_select_difficulty_button(medium_btn)


func _on_hard_pressed() -> void:
	selected_difficulty = "hard"
	_select_difficulty_button(hard_btn)


func _on_custom_pressed() -> void:
	selected_difficulty = "custom"
	_select_difficulty_button(custom_btn)


func _on_min_rating_changed(value: float) -> void:
	if value > max_rating_spinbox.value:
		max_rating_spinbox.value = value


func _on_max_rating_changed(value: float) -> void:
	if value < min_rating_spinbox.value:
		min_rating_spinbox.value = value


func _on_start_pressed() -> void:
	var settings = get_settings()
	start_requested.emit(settings)


func _on_back_pressed() -> void:
	back_requested.emit()


## Get the current settings as a Dictionary.
func get_settings() -> Dictionary:
	var settings = {
		"time_limit": selected_time,
		"difficulty": selected_difficulty
	}

	if selected_difficulty == "custom":
		settings["min_rating"] = int(min_rating_spinbox.value)
		settings["max_rating"] = int(max_rating_spinbox.value)

	return settings
