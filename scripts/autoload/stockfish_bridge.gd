extends Node
## Autoload bridge for chess engine access.
## Selects appropriate engine implementation based on platform.

var engine: EngineInterface = null


func _ready() -> void:
	var os_name = OS.get_name()

	if os_name in ["Windows", "macOS", "Linux"]:
		engine = StockfishProcess.new()
		add_child(engine)
		engine.ready.connect(_on_engine_ready)
		engine.analysis_complete.connect(_on_analysis_complete)
		engine.thinking_started.connect(_on_thinking_started)
		engine.thinking_finished.connect(_on_thinking_finished)
	else:
		push_error("Platform '%s' not supported for chess engine" % os_name)


func _on_engine_ready() -> void:
	print("Chess engine ready")


func _on_analysis_complete(result: Dictionary) -> void:
	# Forward signal for any listeners
	pass


func _on_thinking_started() -> void:
	pass


func _on_thinking_finished() -> void:
	pass


## Analyze a position and return the result.
func analyze_position(fen: String, depth: int = 15) -> Dictionary:
	if engine == null:
		push_error("No engine available")
		return {}
	return engine.analyze_position(fen, depth)


## Get the best move for a position.
func get_best_move(fen: String) -> String:
	if engine == null:
		return ""
	return engine.get_best_move(fen)


## Check if position is mate-in-N.
func is_mate_in_n(fen: String, n: int) -> bool:
	if engine == null:
		return false
	return engine.is_mate_in_n(fen, n)


## Check if engine is ready.
func is_ready() -> bool:
	return engine != null and engine._is_ready if engine.has_method("_is_ready") else false


## Check if currently analyzing.
func is_analyzing() -> bool:
	if engine == null:
		return false
	return engine.is_analyzing()
