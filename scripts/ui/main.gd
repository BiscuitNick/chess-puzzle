class_name Main
extends Control
## Root scene controller with scene switching and navigation management.

# Preloaded scenes for fast access
const MAIN_MENU_SCENE = preload("res://scenes/ui/main_menu.tscn")
const PUZZLE_SCREEN_SCENE = preload("res://scenes/ui/puzzle_screen.tscn")

# Scene paths for lazy loading
const SCENE_PATHS = {
	"main_menu": "res://scenes/ui/main_menu.tscn",
	"puzzle_screen": "res://scenes/ui/puzzle_screen.tscn",
	"practice_setup": "res://scenes/ui/practice_setup.tscn",
	"sprint_setup": "res://scenes/ui/sprint_setup.tscn",
	"sprint_results": "res://scenes/ui/sprint_results.tscn",
	"streak_setup": "res://scenes/ui/streak_setup.tscn",
	"streak_game_over": "res://scenes/ui/streak_game_over.tscn",
	"daily_complete": "res://scenes/ui/daily_complete.tscn",
	"stats_screen": "res://scenes/ui/stats_screen.tscn",
	"settings_menu": "res://scenes/ui/settings_menu.tscn",
	"licenses_screen": "res://scenes/ui/licenses_screen.tscn",
	"game_over_screen": "res://scenes/ui/game_over_screen.tscn"
}

# Transition settings
@export var transition_duration: float = 0.25
@export var default_transition: TransitionType = TransitionType.FADE

enum TransitionType { NONE, FADE, SLIDE_LEFT, SLIDE_RIGHT }

# Node references
@onready var scene_container: Control = $SceneContainer
@onready var transition_overlay: ColorRect = $TransitionOverlay

# Navigation state
var scene_stack: Array[String] = []
var current_scene: Control = null
var current_scene_name: String = ""
var is_transitioning: bool = false


func _ready() -> void:
	add_to_group("game_manager")
	transition_overlay.modulate.a = 0.0
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Start with main menu
	change_scene("main_menu", TransitionType.NONE)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not is_transitioning:
		_handle_back_navigation()


## Change to a new scene, replacing the current one.
func change_scene(scene_name: String, transition: TransitionType = default_transition) -> void:
	if is_transitioning:
		return

	var scene_path = SCENE_PATHS.get(scene_name, scene_name)
	if scene_path.is_empty():
		push_error("Unknown scene: %s" % scene_name)
		return

	await _perform_transition(scene_path, scene_name, transition, false)


## Push a scene onto the stack (for modal/overlay navigation).
func push_scene(scene_name: String, transition: TransitionType = TransitionType.SLIDE_LEFT) -> void:
	if is_transitioning:
		return

	if not current_scene_name.is_empty():
		scene_stack.push_back(current_scene_name)

	var scene_path = SCENE_PATHS.get(scene_name, scene_name)
	if scene_path.is_empty():
		push_error("Unknown scene: %s" % scene_name)
		return

	await _perform_transition(scene_path, scene_name, transition, false)


## Pop the current scene and return to the previous one.
func pop_scene(transition: TransitionType = TransitionType.SLIDE_RIGHT) -> void:
	if is_transitioning or scene_stack.is_empty():
		return

	var previous_scene = scene_stack.pop_back()
	var scene_path = SCENE_PATHS.get(previous_scene, previous_scene)

	await _perform_transition(scene_path, previous_scene, transition, false)


## Go back to main menu, clearing the stack.
func go_to_main_menu(transition: TransitionType = TransitionType.FADE) -> void:
	scene_stack.clear()
	await change_scene("main_menu", transition)


## Check if we can go back.
func can_go_back() -> bool:
	return not scene_stack.is_empty()


## Perform scene transition with animation.
func _perform_transition(scene_path: String, scene_name: String, transition: TransitionType, _is_pop: bool) -> void:
	is_transitioning = true
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Transition out
	if transition != TransitionType.NONE and current_scene != null:
		await _animate_out(transition)

	# Remove old scene
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null

	# Load new scene
	var new_scene = _load_scene(scene_path)
	if new_scene == null:
		is_transitioning = false
		transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	current_scene = new_scene
	current_scene_name = scene_name
	scene_container.add_child(current_scene)

	# Connect navigation signals
	_connect_scene_signals(current_scene)

	# Transition in
	if transition != TransitionType.NONE:
		await _animate_in(transition)

	is_transitioning = false
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Load a scene from path or preload.
func _load_scene(scene_path: String) -> Control:
	var scene: PackedScene

	# Use preloaded scenes if available
	if scene_path == "res://scenes/ui/main_menu.tscn":
		scene = MAIN_MENU_SCENE
	elif scene_path == "res://scenes/ui/puzzle_screen.tscn":
		scene = PUZZLE_SCREEN_SCENE
	else:
		scene = load(scene_path)

	if scene == null:
		push_error("Failed to load scene: %s" % scene_path)
		return null

	return scene.instantiate()


## Connect common navigation signals from scene.
func _connect_scene_signals(scene: Control) -> void:
	# Connect common signals if they exist
	if scene.has_signal("main_menu_requested"):
		scene.connect("main_menu_requested", go_to_main_menu)

	if scene.has_signal("back_requested"):
		scene.connect("back_requested", _on_back_requested)

	if scene.has_signal("scene_change_requested"):
		scene.connect("scene_change_requested", _on_scene_change_requested)

	if scene.has_signal("scene_push_requested"):
		scene.connect("scene_push_requested", _on_scene_push_requested)

	# Connect setup screen signals
	if scene.has_signal("start_requested"):
		_connect_start_signal(scene)


## Connect start_requested signal based on scene type.
func _connect_start_signal(scene: Control) -> void:
	match current_scene_name:
		"practice_setup":
			scene.connect("start_requested", _on_practice_start_requested)
		"sprint_setup":
			scene.connect("start_requested", _on_sprint_start_requested)
		"streak_setup":
			scene.connect("start_requested", _on_streak_start_requested)


## Animate transition out.
func _animate_out(transition: TransitionType) -> void:
	var tween = create_tween()

	match transition:
		TransitionType.FADE:
			tween.tween_property(transition_overlay, "modulate:a", 1.0, transition_duration / 2.0)
		TransitionType.SLIDE_LEFT:
			tween.tween_property(current_scene, "position:x", -size.x, transition_duration / 2.0).set_ease(Tween.EASE_IN)
		TransitionType.SLIDE_RIGHT:
			tween.tween_property(current_scene, "position:x", size.x, transition_duration / 2.0).set_ease(Tween.EASE_IN)

	await tween.finished


## Animate transition in.
func _animate_in(transition: TransitionType) -> void:
	var tween = create_tween()

	match transition:
		TransitionType.FADE:
			tween.tween_property(transition_overlay, "modulate:a", 0.0, transition_duration / 2.0)
		TransitionType.SLIDE_LEFT:
			current_scene.position.x = size.x
			tween.tween_property(current_scene, "position:x", 0.0, transition_duration / 2.0).set_ease(Tween.EASE_OUT)
		TransitionType.SLIDE_RIGHT:
			current_scene.position.x = -size.x
			tween.tween_property(current_scene, "position:x", 0.0, transition_duration / 2.0).set_ease(Tween.EASE_OUT)

	await tween.finished


## Handle back navigation from input.
func _handle_back_navigation() -> void:
	# Check if current scene handles back itself
	if current_scene and current_scene.has_method("handle_back"):
		var handled = current_scene.handle_back()
		if handled:
			return

	# Otherwise pop or go to main menu
	if can_go_back():
		pop_scene()
	elif current_scene_name != "main_menu":
		go_to_main_menu()


func _on_back_requested() -> void:
	if can_go_back():
		pop_scene()
	else:
		go_to_main_menu()


func _on_scene_change_requested(scene_name: String) -> void:
	change_scene(scene_name)


func _on_scene_push_requested(scene_name: String) -> void:
	push_scene(scene_name)


# Game start handlers - these start games with the appropriate mode and settings

## Pending game settings (set before transition, used after puzzle_screen loads)
var pending_game_mode: int = -1
var pending_game_settings: Dictionary = {}


## Start practice mode with settings.
func _on_practice_start_requested(settings: Dictionary) -> void:
	pending_game_mode = PuzzleController.GameMode.PRACTICE
	pending_game_settings = settings
	scene_stack.clear()  # Clear stack so main menu is destination after game
	await change_scene("puzzle_screen")
	_initialize_puzzle_screen()


## Start sprint mode with settings.
func _on_sprint_start_requested(settings: Dictionary) -> void:
	pending_game_mode = PuzzleController.GameMode.SPRINT
	pending_game_settings = settings
	scene_stack.clear()
	await change_scene("puzzle_screen")
	_initialize_puzzle_screen()


## Start streak mode with settings.
func _on_streak_start_requested(settings: Dictionary) -> void:
	pending_game_mode = PuzzleController.GameMode.STREAK
	pending_game_settings = settings
	scene_stack.clear()
	await change_scene("puzzle_screen")
	_initialize_puzzle_screen()


## Initialize the puzzle screen with pending mode and settings.
func _initialize_puzzle_screen() -> void:
	if current_scene and current_scene.has_method("initialize"):
		current_scene.initialize(pending_game_mode, pending_game_settings)
	pending_game_mode = -1
	pending_game_settings = {}


## Show game results screen (called by puzzle_screen via group).
func show_results(results_data: Dictionary) -> void:
	var mode = results_data.get("mode", "")

	# Use mode-specific results screens
	match mode:
		"sprint":
			await change_scene("sprint_results")
			if current_scene and current_scene.has_method("show_results"):
				current_scene.show_results(
					results_data.get("reason", ""),
					results_data.get("stats", {})
				)
		"streak":
			await change_scene("streak_game_over")
			if current_scene and current_scene.has_method("show_results"):
				current_scene.show_results(results_data.get("stats", {}))
		"daily":
			await change_scene("daily_complete")
			if current_scene and current_scene.has_method("show_results"):
				current_scene.show_results(
					results_data.get("results", []),
					results_data.get("score", 0.0),
					results_data.get("streak", 0),
					results_data.get("share_text", "")
				)
		_:
			await change_scene("game_over_screen")
			if current_scene and current_scene.has_method("show_results"):
				current_scene.show_results(mode, results_data.get("stats", {}))
