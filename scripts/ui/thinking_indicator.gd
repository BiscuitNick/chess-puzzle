class_name ThinkingIndicator
extends Control
## Animated indicator shown when engine is analyzing.
## Shows after a configurable delay (default 150ms) to avoid flashing on fast responses.

@onready var label: Label = $Label

## Time between dot animation updates
const DOT_INTERVAL: float = 0.4

## Delay before showing indicator (avoids flashing for quick responses)
@export var show_delay_ms: int = 150

var dot_count: int = 0
var is_animating: bool = false
var dot_timer: float = 0.0
var show_timer: Timer
var pending_show: bool = false


func _ready() -> void:
	visible = false
	if label:
		label.text = "Thinking"

	# Create timer for delayed show
	show_timer = Timer.new()
	show_timer.one_shot = true
	show_timer.timeout.connect(_on_show_timer_timeout)
	add_child(show_timer)


func _process(delta: float) -> void:
	if not is_animating:
		return

	dot_timer += delta
	if dot_timer >= DOT_INTERVAL:
		dot_timer = 0.0
		dot_count = (dot_count + 1) % 4
		var dots = ".".repeat(dot_count)
		if label:
			label.text = "Thinking" + dots


func _on_show_timer_timeout() -> void:
	if pending_show:
		visible = true
		is_animating = true
		dot_count = 0
		dot_timer = 0.0
		if label:
			label.text = "Thinking"


## Start the delayed show - indicator appears after show_delay_ms.
## Call this when engine analysis begins.
func start_thinking() -> void:
	pending_show = true
	show_timer.start(show_delay_ms / 1000.0)


## Immediately hide the indicator and cancel any pending show.
## Call this when engine analysis completes.
func stop_thinking() -> void:
	pending_show = false
	show_timer.stop()
	visible = false
	is_animating = false


## Show the thinking indicator immediately (legacy method).
func show_thinking() -> void:
	pending_show = false
	show_timer.stop()
	visible = true
	is_animating = true
	dot_count = 0
	dot_timer = 0.0
	if label:
		label.text = "Thinking"


## Hide the thinking indicator (legacy method).
func hide_thinking() -> void:
	stop_thinking()
