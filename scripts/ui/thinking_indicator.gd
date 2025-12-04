class_name ThinkingIndicator
extends Control
## Animated indicator shown when engine is analyzing.

@onready var label: Label = $Label
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var dot_count: int = 0
var is_animating: bool = false


func _ready() -> void:
	visible = false
	if label:
		label.text = "Thinking"


func _process(_delta: float) -> void:
	if not is_animating:
		return

	# Simple dot animation
	dot_count = (dot_count + 1) % 4
	var dots = ".".repeat(dot_count)
	if label:
		label.text = "Thinking" + dots


## Show the thinking indicator.
func show_thinking() -> void:
	visible = true
	is_animating = true
	dot_count = 0


## Hide the thinking indicator.
func hide_thinking() -> void:
	visible = false
	is_animating = false
