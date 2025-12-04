class_name StrikeIndicator
extends HBoxContainer
## Visual strike indicator showing 3 strike slots for Sprint Mode.

# Strike icon references (will be set up dynamically or via @onready)
var strike_icons: Array[TextureRect] = []

# Colors for strike states
var unused_color: Color = Color(0.3, 0.3, 0.3, 0.5)  # Gray, semi-transparent
var used_color: Color = Color(0.9, 0.2, 0.2, 1.0)    # Red

# Current strike count
var current_strikes: int = 0

const MAX_STRIKES: int = 3


func _ready() -> void:
	_setup_strike_icons()
	set_strikes(0)


## Set up strike icons if not already present.
func _setup_strike_icons() -> void:
	strike_icons.clear()

	# Check if children already exist
	for child in get_children():
		if child is TextureRect:
			strike_icons.append(child)

	# Create icons if needed
	while strike_icons.size() < MAX_STRIKES:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = unused_color
		add_child(icon)
		strike_icons.append(icon)


## Update the visual state to show the given number of strikes.
func set_strikes(count: int) -> void:
	current_strikes = clampi(count, 0, MAX_STRIKES)

	for i in range(strike_icons.size()):
		var icon = strike_icons[i]
		if i < current_strikes:
			icon.modulate = used_color
		else:
			icon.modulate = unused_color


## Add one strike with animation.
func add_strike() -> void:
	if current_strikes < MAX_STRIKES:
		current_strikes += 1
		_animate_strike(current_strikes - 1)
		set_strikes(current_strikes)


## Animate a strike being added.
func _animate_strike(index: int) -> void:
	if index >= strike_icons.size():
		return

	var icon = strike_icons[index]

	# Scale pop animation
	var tween = create_tween()
	tween.tween_property(icon, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.1)


## Reset to no strikes.
func reset() -> void:
	set_strikes(0)


## Get current strike count.
func get_strikes() -> int:
	return current_strikes
