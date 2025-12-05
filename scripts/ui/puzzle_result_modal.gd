class_name PuzzleResultModal
extends Control
## Modal dialog shown after a puzzle move result (correct/incorrect).

signal try_again_pressed()
signal next_puzzle_pressed()
signal show_solution_pressed()

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var button_container: HBoxContainer = $Panel/VBox/ButtonContainer
@onready var try_again_btn: Button = $Panel/VBox/ButtonContainer/TryAgainButton
@onready var next_puzzle_btn: Button = $Panel/VBox/ButtonContainer/NextPuzzleButton
@onready var solution_btn: Button = $Panel/VBox/ButtonContainer/SolutionButton


func _ready() -> void:
	visible = false

	if try_again_btn:
		try_again_btn.pressed.connect(_on_try_again)
	if next_puzzle_btn:
		next_puzzle_btn.pressed.connect(_on_next_puzzle)
	if solution_btn:
		solution_btn.pressed.connect(_on_show_solution)


## Show the modal for a correct move/puzzle completion.
func show_correct(message: String = "Well done!", show_next: bool = true) -> void:
	title_label.text = "Correct!"
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	message_label.text = message

	try_again_btn.visible = false
	solution_btn.visible = false
	next_puzzle_btn.visible = show_next

	visible = true


## Show the modal for an incorrect move.
func show_incorrect(message: String = "That's not the best move.", show_try_again: bool = true, show_next: bool = false, show_solution: bool = true) -> void:
	title_label.text = "Incorrect"
	title_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	message_label.text = message

	try_again_btn.visible = show_try_again
	next_puzzle_btn.visible = show_next
	solution_btn.visible = show_solution

	visible = true


## Hide the modal.
func hide_modal() -> void:
	visible = false


func _on_try_again() -> void:
	hide_modal()
	try_again_pressed.emit()


func _on_next_puzzle() -> void:
	hide_modal()
	next_puzzle_pressed.emit()


func _on_show_solution() -> void:
	hide_modal()
	show_solution_pressed.emit()
