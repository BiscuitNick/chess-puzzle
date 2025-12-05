class_name StreakCounter
extends HBoxContainer
## In-game streak counter component showing current streak and rating.

@onready var streak_label: Label = $StreakContainer/StreakLabel
@onready var rating_label: Label = $RatingLabel

var current_streak: int = 0
var current_rating: int = 0


func _ready() -> void:
	update_display(0, 0)


## Update the streak display with animation.
func update_streak(count: int) -> void:
	current_streak = count
	_update_streak_label()
	_animate_increment()


## Update the current rating display.
func update_rating(rating: int) -> void:
	current_rating = rating
	_update_rating_label()


## Update full display.
func update_display(streak: int, rating: int) -> void:
	current_streak = streak
	current_rating = rating
	_update_streak_label()
	_update_rating_label()


func _update_streak_label() -> void:
	if streak_label:
		streak_label.text = "%d" % current_streak


func _update_rating_label() -> void:
	if rating_label:
		rating_label.text = "Rating: %d" % current_rating


## Animate streak increment with scale bounce.
func _animate_increment() -> void:
	if not streak_label:
		return

	var tween = create_tween()
	tween.tween_property(streak_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(streak_label, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)


## Reset the counter.
func reset() -> void:
	current_streak = 0
	current_rating = 0
	update_display(0, 0)


## Set the streak count (alias for update_streak).
func set_streak(count: int) -> void:
	update_streak(count)
