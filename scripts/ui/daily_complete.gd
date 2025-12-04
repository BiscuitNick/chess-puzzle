class_name DailyComplete
extends Control
## Daily challenge completion screen with results and share functionality.

## Emitted when user wants to review puzzles
signal review_requested()

## Emitted when user wants to go to main menu
signal main_menu_requested()

# UI element references
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var emoji_grid_label: Label = $VBoxContainer/EmojiGridLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var streak_label: Label = $VBoxContainer/StreakLabel
@onready var copied_label: Label = $VBoxContainer/CopiedLabel

@onready var share_btn: Button = $VBoxContainer/ButtonContainer/ShareButton
@onready var review_btn: Button = $VBoxContainer/ButtonContainer/ReviewButton
@onready var menu_btn: Button = $VBoxContainer/ButtonContainer/MenuButton

# Data
var results: Array = []
var score: float = 0.0
var streak: int = 0
var share_text: String = ""


func _ready() -> void:
	_connect_signals()
	if copied_label:
		copied_label.visible = false


func _connect_signals() -> void:
	share_btn.pressed.connect(_on_share_pressed)
	if review_btn:
		review_btn.pressed.connect(_on_review_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)


## Display results for completed daily challenge.
func show_results(puzzle_results: Array, final_score: float, current_streak: int, generated_share_text: String) -> void:
	results = puzzle_results
	score = final_score
	streak = current_streak
	share_text = generated_share_text
	visible = true

	# Calculate solved count
	var solved_count = 0
	for result in results:
		if result.solved:
			solved_count += 1

	# Update title based on performance
	if solved_count == 5:
		title_label.text = "Perfect Day! 🏆"
	elif solved_count >= 3:
		title_label.text = "Daily Complete!"
	else:
		title_label.text = "Daily Finished"

	# Build emoji grid
	var emoji_grid = ""
	for result in results:
		emoji_grid += "🟩" if result.solved else "⬛"
	emoji_grid_label.text = emoji_grid

	# Display score
	var max_score = 5.0 + 2.5  # 5 puzzles + 5 perfect bonuses
	score_label.text = "Score: %.1f / %.1f" % [score, max_score]

	# Display streak
	if streak > 1:
		streak_label.text = "🔥 Streak: %d days" % streak
		streak_label.visible = true
	else:
		streak_label.visible = false


func _on_share_pressed() -> void:
	DisplayServer.clipboard_set(share_text)

	# Show "Copied!" feedback
	if copied_label:
		copied_label.visible = true
		copied_label.text = "Copied to clipboard!"

		# Hide after 2 seconds
		await get_tree().create_timer(2.0).timeout
		if copied_label:
			copied_label.visible = false


func _on_review_pressed() -> void:
	review_requested.emit()


func _on_menu_pressed() -> void:
	main_menu_requested.emit()
