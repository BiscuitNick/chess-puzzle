class_name PracticeSetup
extends Control
## Practice mode setup screen with puzzle filters and options.

## Emitted when user clicks start with configured settings
signal start_requested(settings: Dictionary)

## Emitted when user wants to go back
signal back_requested()

# UI element references
@onready var mate_depth_option: OptionButton = $VBoxContainer/MateDepthSection/MateDepthOption
@onready var challenge_toggle: CheckButton = $VBoxContainer/MateDepthSection/ChallengeToggle
@onready var min_rating_slider: HSlider = $VBoxContainer/RatingSection/MinRatingContainer/MinRatingSlider
@onready var max_rating_slider: HSlider = $VBoxContainer/RatingSection/MaxRatingContainer/MaxRatingSlider
@onready var min_rating_label: Label = $VBoxContainer/RatingSection/MinRatingContainer/MinRatingLabel
@onready var max_rating_label: Label = $VBoxContainer/RatingSection/MaxRatingContainer/MaxRatingLabel
@onready var random_button: Button = $VBoxContainer/OrderSection/OrderButtons/RandomButton
@onready var progressive_button: Button = $VBoxContainer/OrderSection/OrderButtons/ProgressiveButton
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var back_button: Button = $VBoxContainer/BackButton

# Default settings
const DEFAULT_MIN_RATING: int = 800
const DEFAULT_MAX_RATING: int = 1600
const MIN_RATING: int = 400
const MAX_RATING: int = 3000
const RATING_STEP: int = 50


func _ready() -> void:
	_setup_mate_depth_options()
	_setup_rating_sliders()
	_setup_order_buttons()
	_connect_signals()


func _setup_mate_depth_options() -> void:
	mate_depth_option.clear()
	mate_depth_option.add_item("All", 0)
	mate_depth_option.add_item("Mate in 1", 1)
	mate_depth_option.add_item("Mate in 2", 2)
	mate_depth_option.add_item("Mate in 3", 3)
	mate_depth_option.add_item("Mate in 4", 4)
	mate_depth_option.add_item("Mate in 5", 5)
	mate_depth_option.select(0)


func _setup_rating_sliders() -> void:
	min_rating_slider.min_value = MIN_RATING
	min_rating_slider.max_value = MAX_RATING
	min_rating_slider.step = RATING_STEP
	min_rating_slider.value = DEFAULT_MIN_RATING

	max_rating_slider.min_value = MIN_RATING
	max_rating_slider.max_value = MAX_RATING
	max_rating_slider.step = RATING_STEP
	max_rating_slider.value = DEFAULT_MAX_RATING

	_update_rating_labels()


func _setup_order_buttons() -> void:
	# Random is default selected
	random_button.button_pressed = true
	progressive_button.button_pressed = false


func _connect_signals() -> void:
	min_rating_slider.value_changed.connect(_on_min_rating_changed)
	max_rating_slider.value_changed.connect(_on_max_rating_changed)
	challenge_toggle.toggled.connect(_on_challenge_toggled)
	random_button.pressed.connect(_on_random_pressed)
	progressive_button.pressed.connect(_on_progressive_pressed)
	start_button.pressed.connect(_on_start_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _update_rating_labels() -> void:
	min_rating_label.text = str(int(min_rating_slider.value))
	max_rating_label.text = str(int(max_rating_slider.value))


func _on_min_rating_changed(value: float) -> void:
	# Ensure min doesn't exceed max
	if value > max_rating_slider.value:
		max_rating_slider.value = value
	_update_rating_labels()


func _on_max_rating_changed(value: float) -> void:
	# Ensure max doesn't go below min
	if value < min_rating_slider.value:
		min_rating_slider.value = value
	_update_rating_labels()


func _on_challenge_toggled(enabled: bool) -> void:
	if enabled:
		# Add mate in 6+ option
		if mate_depth_option.item_count <= 6:
			mate_depth_option.add_item("Mate in 6+", 6)
	else:
		# Remove mate in 6+ option if it exists
		if mate_depth_option.item_count > 6:
			mate_depth_option.remove_item(6)
			# If was selected, switch to All
			if mate_depth_option.selected >= mate_depth_option.item_count:
				mate_depth_option.select(0)


func _on_random_pressed() -> void:
	random_button.button_pressed = true
	progressive_button.button_pressed = false


func _on_progressive_pressed() -> void:
	progressive_button.button_pressed = true
	random_button.button_pressed = false


func _on_start_pressed() -> void:
	var settings = get_settings()
	start_requested.emit(settings)


func _on_back_pressed() -> void:
	back_requested.emit()


## Get the current settings as a Dictionary.
func get_settings() -> Dictionary:
	var mate_depth = mate_depth_option.get_selected_id()
	# For "Mate in 6+", we pass 6 and set challenge_mode true
	if mate_depth == 6:
		mate_depth = 6

	return {
		"mate_depth": mate_depth,
		"min_rating": int(min_rating_slider.value),
		"max_rating": int(max_rating_slider.value),
		"order": "random" if random_button.button_pressed else "progressive",
		"challenge_mode": challenge_toggle.button_pressed
	}


## Set settings from a Dictionary (for restoring previous settings).
func set_settings(settings: Dictionary) -> void:
	if settings.has("mate_depth"):
		var depth = settings.mate_depth
		# Enable challenge mode if needed for mate depth 6
		if depth >= 6 and not challenge_toggle.button_pressed:
			challenge_toggle.button_pressed = true
			_on_challenge_toggled(true)
		for i in range(mate_depth_option.item_count):
			if mate_depth_option.get_item_id(i) == depth:
				mate_depth_option.select(i)
				break

	if settings.has("min_rating"):
		min_rating_slider.value = settings.min_rating

	if settings.has("max_rating"):
		max_rating_slider.value = settings.max_rating

	if settings.has("order"):
		if settings.order == "random":
			_on_random_pressed()
		else:
			_on_progressive_pressed()

	if settings.has("challenge_mode"):
		challenge_toggle.button_pressed = settings.challenge_mode
