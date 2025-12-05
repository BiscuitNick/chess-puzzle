class_name PuzzleValidator
extends RefCounted
## Validates puzzle moves using Stockfish analysis.
## Checks that moves maintain forced mate and verifies checkmate delivery.

const ChessLogicScript = preload("res://scripts/autoload/chess_logic.gd")


## Validate a player move in a puzzle.
## Returns a Dictionary with: valid, is_checkmate, new_mate_in, reason
func validate_move(fen: String, move_uci: String, expected_mate_in: int) -> Dictionary:
	var result = {
		"valid": false,
		"is_checkmate": false,
		"new_mate_in": -1,
		"reason": ""
	}

	# Make the move in a temporary state to check the resulting position
	var temp_logic = ChessLogicScript.new()
	temp_logic._ready()
	temp_logic.parse_fen(fen)

	var move_data = temp_logic.uci_to_squares(move_uci)
	if move_data["from"] < 0 or move_data["to"] < 0:
		result["reason"] = "Invalid move format"
		return result

	# Check if move is legal
	if not temp_logic.is_move_legal(move_data["from"], move_data["to"]):
		result["reason"] = "Illegal move"
		return result

	# Make the move
	temp_logic.make_move(move_data["from"], move_data["to"], move_data["promotion"])

	# Check if this delivers checkmate
	if temp_logic.is_checkmate():
		result["valid"] = true
		result["is_checkmate"] = true
		result["new_mate_in"] = 0
		return result

	# If not checkmate, check if we still have a forced mate
	var new_fen = temp_logic.to_fen()
	var analysis = await _analyze_position(new_fen)

	if analysis["is_mate"]:
		var mate_distance = abs(analysis["mate_in"])

		# Accept moves that maintain mate or find faster mate
		# Note: After our move, it's opponent's turn, so mate_in will be negative
		# (opponent is getting mated in N moves from their perspective)
		if mate_distance <= expected_mate_in:
			result["valid"] = true
			result["new_mate_in"] = mate_distance
		else:
			result["reason"] = "Move doesn't maintain forced mate (mate in %d instead of %d)" % [mate_distance, expected_mate_in]
	else:
		result["reason"] = "Move loses the forced mate"

	return result


## Analyze a position using Stockfish.
func _analyze_position(fen: String) -> Dictionary:
	var result = {
		"is_mate": false,
		"mate_in": 0,
		"score_cp": 0
	}

	# Use StockfishBridge if available
	if Engine.has_singleton("StockfishBridge"):
		var bridge = Engine.get_singleton("StockfishBridge")
		var analysis = bridge.analyze_position(fen, 15)
		result["is_mate"] = analysis.get("is_mate", false)
		result["mate_in"] = analysis.get("mate_in", 0)
		result["score_cp"] = analysis.get("score_cp", 0)
	else:
		# Fallback: try to get the autoload
		var bridge = _get_stockfish_bridge()
		if bridge and bridge.engine:
			var analysis = bridge.engine.analyze_position(fen, 15)
			result["is_mate"] = analysis.get("is_mate", false)
			result["mate_in"] = analysis.get("mate_in", 0)
			result["score_cp"] = analysis.get("score_cp", 0)

	return result


func _get_stockfish_bridge():
	# Try to get the StockfishBridge from the scene tree
	var root = Engine.get_main_loop()
	if root and root is SceneTree:
		return root.root.get_node_or_null("/root/StockfishBridge")
	return null


## Check if a position is checkmate.
func is_checkmate(fen: String) -> bool:
	var temp_logic = ChessLogicScript.new()
	temp_logic._ready()
	temp_logic.parse_fen(fen)
	return temp_logic.is_checkmate()


## Get the mate distance from a position.
## Returns -1 if there's no forced mate.
func get_mate_distance(fen: String) -> int:
	var analysis = await _analyze_position(fen)
	if analysis["is_mate"]:
		return abs(analysis["mate_in"])
	return -1


## Check if an alternate mate line is acceptable.
## Faster mates are acceptable, slower mates are not.
func accepts_alternate_mate(expected_mate: int, actual_mate: int) -> bool:
	return actual_mate <= expected_mate and actual_mate > 0


## Get the best move from a position using Stockfish.
func get_best_move(fen: String) -> String:
	var bridge = _get_stockfish_bridge()
	if bridge and bridge.engine:
		return bridge.engine.get_best_move(fen)
	return ""


## Validate that a puzzle's solution actually delivers checkmate.
## Returns a Dictionary with: valid, reason
func validate_puzzle(puzzle) -> Dictionary:
	var result = {
		"valid": false,
		"reason": ""
	}

	if not puzzle:
		result["reason"] = "Puzzle is null"
		return result

	if puzzle.solution_moves.is_empty():
		result["reason"] = "Puzzle has no solution moves"
		return result

	# Create temp logic to apply moves
	var temp_logic = ChessLogicScript.new()
	temp_logic._ready()

	# Parse initial position
	temp_logic.parse_fen(puzzle.fen)

	# Check if already checkmate before any moves
	if temp_logic.is_checkmate():
		result["reason"] = "Position is already checkmate before puzzle starts"
		return result

	# Apply all solution moves
	for i in range(puzzle.solution_moves.size()):
		var move_uci = puzzle.solution_moves[i]
		var move_data = temp_logic.uci_to_squares(move_uci)

		if move_data["from"] < 0 or move_data["to"] < 0:
			result["reason"] = "Invalid move format at index %d: %s" % [i, move_uci]
			return result

		if not temp_logic.is_move_legal(move_data["from"], move_data["to"]):
			result["reason"] = "Illegal move at index %d: %s" % [i, move_uci]
			return result

		temp_logic.make_move(move_data["from"], move_data["to"], move_data["promotion"])

	# After all moves, position must be checkmate
	if temp_logic.is_checkmate():
		result["valid"] = true
	else:
		result["reason"] = "Final position is not checkmate"

	return result
