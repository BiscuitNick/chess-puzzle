class_name TimerDisplay
extends MarginContainer
## Visual timer display component for Sprint Mode.

@onready var time_label: Label = $TimeLabel

# Color thresholds
const WARNING_TIME: float = 30.0
const CRITICAL_TIME: float = 10.0

# Colors
var normal_color: Color = Color.WHITE
var warning_color: Color = Color.YELLOW
var critical_color: Color = Color.RED

# Pulse animation for critical time
var pulse_tween: Tween
var is_pulsing: bool = false


func _ready() -> void:
	if time_label:
		time_label.text = "0:00"


## Update the display with remaining time in seconds.
func update_time(seconds: float) -> void:
	if not time_label:
		return

	# Format time as MM:SS
	var total_seconds = int(max(0, seconds))
	var minutes = total_seconds / 60
	var secs = total_seconds % 60
	time_label.text = "%d:%02d" % [minutes, secs]

	# Update color based on remaining time
	if seconds <= CRITICAL_TIME:
		time_label.modulate = critical_color
		_start_pulse()
	elif seconds <= WARNING_TIME:
		time_label.modulate = warning_color
		_stop_pulse()
	else:
		time_label.modulate = normal_color
		_stop_pulse()


## Start pulse animation for critical time.
func _start_pulse() -> void:
	if is_pulsing:
		return

	is_pulsing = true
	_do_pulse()


## Stop pulse animation.
func _stop_pulse() -> void:
	if pulse_tween:
		pulse_tween.kill()
	is_pulsing = false
	if time_label:
		time_label.scale = Vector2.ONE


## Perform one pulse cycle.
func _do_pulse() -> void:
	if not is_pulsing or not time_label:
		return

	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(time_label, "scale", Vector2(1.1, 1.1), 0.3)
	pulse_tween.tween_property(time_label, "scale", Vector2.ONE, 0.3)


## Reset display to initial state.
func reset() -> void:
	_stop_pulse()
	if time_label:
		time_label.text = "0:00"
		time_label.modulate = normal_color
