class_name EngineInterface
extends Node
## Abstract base class for chess engine implementations.
## Provides the interface for analyzing positions and getting best moves.

## Emitted when analysis of a position is complete.
## result: Dictionary with keys: best_move, is_mate, mate_in, score_cp
signal analysis_complete(result: Dictionary)

## Emitted when the engine is ready to receive commands.
signal engine_ready

## Emitted when the engine starts thinking (after threshold delay).
signal thinking_started

## Emitted when the engine finishes thinking.
signal thinking_finished


## Analyze a chess position and return detailed analysis.
## fen: The position in FEN notation
## depth: Search depth (higher = stronger but slower)
## Returns: Dictionary with best_move, is_mate, mate_in, score_cp
func analyze_position(fen: String, depth: int = 15) -> Dictionary:
	push_error("EngineInterface.analyze_position() must be overridden by subclass")
	return {}


## Get the best move for a position.
## fen: The position in FEN notation
## Returns: Best move in UCI notation (e.g., "e2e4") or empty string on error
func get_best_move(fen: String) -> String:
	push_error("EngineInterface.get_best_move() must be overridden by subclass")
	return ""


## Check if a position is mate-in-N.
## fen: The position in FEN notation
## n: The number of moves to mate
## Returns: true if the position is exactly mate-in-N for the side to move
func is_mate_in_n(fen: String, n: int) -> bool:
	push_error("EngineInterface.is_mate_in_n() must be overridden by subclass")
	return false


## Check if the engine is currently analyzing.
func is_analyzing() -> bool:
	push_error("EngineInterface.is_analyzing() must be overridden by subclass")
	return false


## Stop any ongoing analysis.
func stop_analysis() -> void:
	push_error("EngineInterface.stop_analysis() must be overridden by subclass")
