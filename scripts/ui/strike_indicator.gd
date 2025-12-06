class_name StrikeIndicator
extends HBoxContainer
## Visual strike indicator showing strike slots for Sprint/Daily modes.
## Uses X symbols to clearly show used strikes.

# Strike icon references (Labels displaying X)
var strike_labels: Array[Label] = []

# Colors for strike states
var unused_color: Color = Color(0.4, 0.4, 0.4, 0.4)  # Gray, semi-transparent
var used_color: Color = Color(0.95, 0.2, 0.2, 1.0)   # Bright red
var danger_color: Color = Color(1.0, 0.4, 0.1, 1.0)  # Orange-red for danger state

# Current strike count
var current_strikes: int = 0

const MAX_STRIKES: int = 3


func _ready() -> void:
	_setup_strike_labels()
	set_strikes(0)


## Set up strike labels if not already present.
func _setup_strike_labels() -> void:
	strike_labels.clear()

	# Clear existing children
	for child in get_children():
		child.queue_free()

	# Create X labels for each strike slot
	for i in range(MAX_STRIKES):
		var label = Label.new()
		label.text = "X"
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", unused_color)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(28, 28)
		add_child(label)
		strike_labels.append(label)


## Update the visual state to show the given number of strikes.
func set_strikes(count: int) -> void:
	current_strikes = clampi(count, 0, MAX_STRIKES)

	for i in range(strike_labels.size()):
		var label = strike_labels[i]
		if i < current_strikes:
			# Used strike - red
			label.add_theme_color_override("font_color", used_color)
		else:
			# Unused strike - gray
			label.add_theme_color_override("font_color", unused_color)

	# Add danger state visual when at 2/3 strikes
	_update_danger_state()


## Update danger state visual (pulsing when close to max strikes).
func _update_danger_state() -> void:
	if current_strikes >= MAX_STRIKES - 1 and current_strikes < MAX_STRIKES:
		# At 2 strikes - show danger state on last slot
		var last_unused = strike_labels[current_strikes] if current_strikes < strike_labels.size() else null
		if last_unused:
			last_unused.add_theme_color_override("font_color", danger_color)


## Add one strike with animation.
func add_strike() -> void:
	if current_strikes < MAX_STRIKES:
		current_strikes += 1
		_animate_strike(current_strikes - 1)
		set_strikes(current_strikes)


## Animate a strike being added.
func _animate_strike(index: int) -> void:
	if index >= strike_labels.size():
		return

	var label = strike_labels[index]
	var pop_scale = GameSettings.strike_pop_scale
	var pop_duration = GameSettings.strike_pop_duration / 2.0

	# Scale pop animation with color flash
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(pop_scale, pop_scale), pop_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, pop_duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Reset to no strikes.
func reset() -> void:
	set_strikes(0)


## Get current strike count.
func get_strikes() -> int:
	return current_strikes


## Check if max strikes reached.
func is_maxed() -> bool:
	return current_strikes >= MAX_STRIKES
