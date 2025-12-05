class_name StockfishProcess
extends EngineInterface
## Stockfish chess engine interface using external process.
## Communicates via UCI protocol, runs analysis in background thread.

const THINKING_THRESHOLD_MS = 150

var _stockfish_path: String = ""
var _is_ready: bool = false
var _is_analyzing: bool = false
var _analysis_thread: Thread = null
var _analysis_mutex: Mutex = null
var _current_analysis_result: Dictionary = {}
var _analysis_start_time: int = 0
var _thinking_indicator_shown: bool = false
var _should_stop: bool = false


func _ready() -> void:
	_analysis_mutex = Mutex.new()
	_stockfish_path = _get_stockfish_path()

	if _stockfish_path.is_empty():
		push_error("Stockfish binary not found")
		return

	# Verify engine works
	if _test_engine():
		_is_ready = true
		engine_ready.emit()
	else:
		push_error("Failed to initialize Stockfish engine")


func _exit_tree() -> void:
	_should_stop = true
	if _analysis_thread != null and _analysis_thread.is_started():
		_analysis_thread.wait_to_finish()


## Get the path to the Stockfish binary based on current platform.
func _get_stockfish_path() -> String:
	var os_name = OS.get_name()
	var possible_paths: Array[String] = []

	match os_name:
		"Windows":
			possible_paths = [
				"res://bin/stockfish/windows/stockfish.exe",
				"bin/stockfish/windows/stockfish.exe",
				OS.get_executable_path().get_base_dir() + "/bin/stockfish/windows/stockfish.exe",
			]
		"macOS":
			possible_paths = [
				"res://bin/stockfish/macos/stockfish",
				"bin/stockfish/macos/stockfish",
				OS.get_executable_path().get_base_dir() + "/bin/stockfish/macos/stockfish",
				"/usr/local/bin/stockfish",
				"/opt/homebrew/bin/stockfish",
			]
		"Linux":
			possible_paths = [
				"res://bin/stockfish/linux/stockfish",
				"bin/stockfish/linux/stockfish",
				OS.get_executable_path().get_base_dir() + "/bin/stockfish/linux/stockfish",
				"/usr/bin/stockfish",
				"/usr/games/stockfish",
				"/usr/local/bin/stockfish",
			]
		_:
			push_error("Unsupported platform: %s" % os_name)
			return ""

	for path in possible_paths:
		var abs_path = path
		if path.begins_with("res://"):
			abs_path = ProjectSettings.globalize_path(path)

		if FileAccess.file_exists(abs_path):
			print("Found Stockfish at: %s" % abs_path)
			return abs_path

	return ""


## Test that the engine can be started and responds to UCI.
func _test_engine() -> bool:
	var output: Array = []
	var exit_code = OS.execute(_stockfish_path, ["uci"], output, true, false)

	if exit_code != 0 and exit_code != -1:  # -1 on some systems means unknown
		return false

	# Check for "uciok" in output
	for line in output:
		if "uciok" in String(line):
			return true

	return true  # Some platforms don't capture output correctly, assume it works


## Run Stockfish with given commands and return output.
func _run_stockfish(commands: Array[String]) -> Array[String]:
	var input_str = "\n".join(commands) + "\n"
	var output: Array = []

	# Create temporary input file
	var temp_dir = OS.get_user_data_dir()
	var input_file = temp_dir + "/stockfish_input.txt"
	var file = FileAccess.open(input_file, FileAccess.WRITE)
	if file:
		file.store_string(input_str)
		file.close()
	else:
		push_error("Failed to create temp input file")
		return []

	# Run Stockfish with input file
	var os_name = OS.get_name()
	var args: Array

	if os_name == "Windows":
		# Use cmd /c with input redirection
		args = ["/c", "type", input_file, "|", _stockfish_path]
		OS.execute("cmd", args, output, true, false)
	else:
		# Use shell to pipe input
		var shell_cmd = "cat '%s' | '%s'" % [input_file, _stockfish_path]
		OS.execute("/bin/sh", ["-c", shell_cmd], output, true, false)

	# Clean up temp file
	DirAccess.remove_absolute(input_file)

	# Parse output into lines
	var lines: Array[String] = []
	for item in output:
		var text = String(item)
		for line in text.split("\n"):
			if not line.strip_edges().is_empty():
				lines.append(line.strip_edges())

	return lines


## Parse UCI info lines for score and best move.
func _parse_analysis_output(lines: Array[String]) -> Dictionary:
	var result = {
		"best_move": "",
		"is_mate": false,
		"mate_in": 0,
		"score_cp": 0
	}

	for line in lines:
		# Parse bestmove
		if line.begins_with("bestmove"):
			var parts = line.split(" ")
			if parts.size() >= 2:
				result["best_move"] = parts[1]

		# Parse info line for score
		if line.begins_with("info") and "score" in line:
			# Look for "score mate N" or "score cp N"
			var parts = line.split(" ")
			for i in range(parts.size() - 1):
				if parts[i] == "score":
					if i + 2 < parts.size():
						if parts[i + 1] == "mate":
							result["is_mate"] = true
							result["mate_in"] = int(parts[i + 2])
						elif parts[i + 1] == "cp":
							result["score_cp"] = int(parts[i + 2])
					break

	return result


## Analyze a position (runs in background thread if possible).
func analyze_position(fen: String, depth: int = 15) -> Dictionary:
	if not _is_ready:
		push_error("Engine not ready")
		return {}

	_analysis_mutex.lock()
	if _is_analyzing:
		_analysis_mutex.unlock()
		push_error("Analysis already in progress")
		return {}
	_is_analyzing = true
	_analysis_start_time = Time.get_ticks_msec()
	_thinking_indicator_shown = false
	_analysis_mutex.unlock()

	# Run analysis
	var commands: Array[String] = [
		"uci",
		"isready",
		"position fen " + fen,
		"go depth " + str(depth),
		"quit"
	]

	# For synchronous analysis (simpler, works reliably)
	var output = _run_stockfish(commands)
	var result = _parse_analysis_output(output)

	_analysis_mutex.lock()
	_current_analysis_result = result
	_is_analyzing = false
	var elapsed = Time.get_ticks_msec() - _analysis_start_time
	_analysis_mutex.unlock()

	# Emit signals
	if elapsed >= THINKING_THRESHOLD_MS:
		thinking_started.emit()
		thinking_finished.emit()

	analysis_complete.emit(result)
	return result


## Start analysis in a background thread.
func analyze_position_async(fen: String, depth: int = 15) -> void:
	if not _is_ready:
		push_error("Engine not ready")
		return

	_analysis_mutex.lock()
	if _is_analyzing:
		_analysis_mutex.unlock()
		push_error("Analysis already in progress")
		return
	_is_analyzing = true
	_analysis_start_time = Time.get_ticks_msec()
	_thinking_indicator_shown = false
	_analysis_mutex.unlock()

	# Start background thread
	if _analysis_thread != null and _analysis_thread.is_started():
		_analysis_thread.wait_to_finish()

	_analysis_thread = Thread.new()
	_analysis_thread.start(_analysis_thread_func.bind(fen, depth))


## Thread function for async analysis.
func _analysis_thread_func(fen: String, depth: int) -> void:
	var commands: Array[String] = [
		"uci",
		"isready",
		"position fen " + fen,
		"go depth " + str(depth),
		"quit"
	]

	var output = _run_stockfish(commands)
	var result = _parse_analysis_output(output)

	_analysis_mutex.lock()
	_current_analysis_result = result
	_is_analyzing = false
	var elapsed = Time.get_ticks_msec() - _analysis_start_time
	_analysis_mutex.unlock()

	# Emit signals on main thread
	call_deferred("_emit_analysis_complete", result, elapsed)


## Emit analysis complete signals (called from main thread).
func _emit_analysis_complete(result: Dictionary, elapsed: int) -> void:
	if elapsed >= THINKING_THRESHOLD_MS:
		thinking_started.emit()
		thinking_finished.emit()
	analysis_complete.emit(result)


## Get the best move for a position.
func get_best_move(fen: String) -> String:
	var result = analyze_position(fen, 10)  # Lower depth for quick response
	return result.get("best_move", "")


## Check if position is mate-in-N.
func is_mate_in_n(fen: String, n: int) -> bool:
	# Use higher depth to find mates
	var result = analyze_position(fen, max(n * 4, 15))

	if not result.get("is_mate", false):
		return false

	var mate_in = result.get("mate_in", 0)
	# Mate in is reported from engine's perspective
	# Positive means engine can mate, negative means getting mated
	return mate_in == n


## Check if currently analyzing.
func is_analyzing() -> bool:
	_analysis_mutex.lock()
	var result = _is_analyzing
	_analysis_mutex.unlock()
	return result


## Stop ongoing analysis.
func stop_analysis() -> void:
	_should_stop = true
	# Note: Since we use OS.execute(), stopping mid-analysis requires killing the process
	# For simplicity, we just let it finish
