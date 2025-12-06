extends Node
class_name GameSettingsClass
## Centralized game settings for animations, timings, and UI behavior.
## Access via the GameSettings autoload singleton.

# === Animation Settings ===

## Duration of board shake on wrong move (seconds)
var wrong_move_shake_duration: float = 0.4

## Intensity of board shake (pixels)
var wrong_move_shake_intensity: float = 8.0

## Duration of red flash on wrong move (seconds)
var wrong_move_flash_duration: float = 0.3

## Color of wrong move flash
var wrong_move_flash_color: Color = Color(1.0, 0.3, 0.3, 0.4)

## Duration of piece move animation (seconds)
var piece_move_duration: float = 0.15

## Duration of strike pop animation (seconds)
var strike_pop_duration: float = 0.2

## Scale factor for strike pop animation
var strike_pop_scale: float = 1.3


# === Timing Settings ===

## Delay before auto-reverting wrong move in practice mode (seconds)
var wrong_move_revert_delay: float = 0.5

## Delay before auto-advancing to next puzzle (seconds)
var auto_advance_delay: float = 1.0

## Delay before opponent makes their move (seconds)
var opponent_move_delay: float = 0.3

## Delay before showing "Thinking..." indicator (seconds)
var thinking_indicator_delay: float = 0.15

## Interval between "Thinking" dot updates (seconds)
var thinking_dot_interval: float = 0.4


# === Behavior Settings ===

## Whether to auto-advance after solving (per mode)
var practice_auto_advance: bool = false
var sprint_auto_advance: bool = true
var streak_auto_advance: bool = true
var daily_auto_advance: bool = true

## Whether to show legal move highlights
var show_legal_moves: bool = true

## Whether to play sound effects
var sound_enabled: bool = true

## Whether to show hint after N wrong attempts (0 = never)
var auto_hint_after_wrong_moves: int = 0


# === Board Colors (for easy theming) ===

## Light square color
var board_light_color: Color = Color("#F0D9B5")

## Dark square color
var board_dark_color: Color = Color("#B58863")

## Last move highlight color
var last_move_highlight_color: Color = Color("#CDD26A", 0.5)

## Selected square color
var selected_square_color: Color = Color("#646D40", 0.7)

## Legal move indicator color
var legal_move_color: Color = Color("#646D40", 0.6)

## Hint highlight color
var hint_color: Color = Color("#4A90D9", 0.8)


# === Methods ===

## Get auto-advance setting for a specific game mode.
func get_auto_advance_for_mode(mode: int) -> bool:
	match mode:
		0: return practice_auto_advance  # PRACTICE
		1: return sprint_auto_advance    # SPRINT
		2: return streak_auto_advance    # STREAK
		3: return daily_auto_advance     # DAILY
		_: return false


## Reset all settings to defaults.
func reset_to_defaults() -> void:
	# Animation
	wrong_move_shake_duration = 0.4
	wrong_move_shake_intensity = 8.0
	wrong_move_flash_duration = 0.3
	wrong_move_flash_color = Color(1.0, 0.3, 0.3, 0.4)
	piece_move_duration = 0.15
	strike_pop_duration = 0.2
	strike_pop_scale = 1.3

	# Timing
	wrong_move_revert_delay = 0.5
	auto_advance_delay = 1.0
	opponent_move_delay = 0.3
	thinking_indicator_delay = 0.15
	thinking_dot_interval = 0.4

	# Behavior
	practice_auto_advance = false
	sprint_auto_advance = true
	streak_auto_advance = true
	daily_auto_advance = true
	show_legal_moves = true
	sound_enabled = true
	auto_hint_after_wrong_moves = 0

	# Colors
	board_light_color = Color("#F0D9B5")
	board_dark_color = Color("#B58863")
	last_move_highlight_color = Color("#CDD26A", 0.5)
	selected_square_color = Color("#646D40", 0.7)
	legal_move_color = Color("#646D40", 0.6)
	hint_color = Color("#4A90D9", 0.8)
