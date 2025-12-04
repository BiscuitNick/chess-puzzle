class_name DailyProgress
extends HBoxContainer
## Visual progress indicator for daily challenge (5 puzzle squares).

const PENDING_COLOR = Color(0.3, 0.3, 0.35, 1.0)
const CURRENT_COLOR = Color(0.4, 0.6, 0.9, 1.0)
const SOLVED_COLOR = Color(0.3, 0.8, 0.3, 1.0)
const FAILED_COLOR = Color(0.2, 0.2, 0.25, 1.0)

var squares: Array[ColorRect] = []
var results: Array[int] = [-1, -1, -1, -1, -1]  # -1 pending, 0 failed, 1 solved
var current_index: int = 0


func _ready() -> void:
	_create_squares()


func _create_squares() -> void:
	for i in range(5):
		var square = ColorRect.new()
		square.custom_minimum_size = Vector2(30, 30)
		square.color = PENDING_COLOR
		add_child(square)
		squares.append(square)


## Set the current puzzle index.
func set_current(index: int) -> void:
	current_index = index
	_update_display()


## Set the result for a puzzle.
func set_result(index: int, solved: bool) -> void:
	if index >= 0 and index < 5:
		results[index] = 1 if solved else 0
		_update_display()


## Reset for new daily.
func reset() -> void:
	results = [-1, -1, -1, -1, -1]
	current_index = 0
	_update_display()


func _update_display() -> void:
	for i in range(5):
		if i >= squares.size():
			continue

		if results[i] == 1:
			squares[i].color = SOLVED_COLOR
		elif results[i] == 0:
			squares[i].color = FAILED_COLOR
		elif i == current_index:
			squares[i].color = CURRENT_COLOR
		else:
			squares[i].color = PENDING_COLOR
