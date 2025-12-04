class_name PuzzleData
extends RefCounted
## Encapsulates all data for a single chess puzzle.

## Unique puzzle identifier (from Lichess database)
var id: String

## Starting position in FEN notation
var fen: String

## Solution moves in UCI notation (e.g., ["e2e4", "e7e5", "d1h5"])
## Alternates between opponent and player moves
var solution_moves: Array[String]

## Puzzle difficulty rating (Lichess rating)
var rating: int

## Number of moves to checkmate
var mate_in: int

## Puzzle themes (e.g., "mateIn2", "backRankMate")
var themes: Array[String]


func _init(
	puzzle_id: String = "",
	puzzle_fen: String = "",
	moves: Array[String] = [],
	puzzle_rating: int = 0,
	mate_depth: int = 0,
	puzzle_themes: Array[String] = []
) -> void:
	id = puzzle_id
	fen = puzzle_fen
	solution_moves = moves
	rating = puzzle_rating
	mate_in = mate_depth
	themes = puzzle_themes


## Get the total number of moves in the solution.
func get_move_count() -> int:
	return solution_moves.size()


## Get the move at the given index.
## Returns empty string if index is out of bounds.
func get_current_move(index: int) -> String:
	if index < 0 or index >= solution_moves.size():
		return ""
	return solution_moves[index]


## Check if the given index is the final move.
func is_final_move(index: int) -> bool:
	return index == solution_moves.size() - 1


## Create PuzzleData from a dictionary (for database loading).
static func from_dict(data: Dictionary) -> PuzzleData:
	var moves: Array[String] = []
	var raw_moves = data.get("moves", "")
	if raw_moves is String:
		for move in raw_moves.split(" "):
			if not move.is_empty():
				moves.append(move)
	elif raw_moves is Array:
		for move in raw_moves:
			moves.append(str(move))

	var puzzle_themes: Array[String] = []
	var raw_themes = data.get("themes", "")
	if raw_themes is String:
		for theme in raw_themes.split(" "):
			if not theme.is_empty():
				puzzle_themes.append(theme)
	elif raw_themes is Array:
		for theme in raw_themes:
			puzzle_themes.append(str(theme))

	return PuzzleData.new(
		str(data.get("id", "")),
		str(data.get("fen", "")),
		moves,
		int(data.get("rating", 0)),
		int(data.get("mate_in", 0)),
		puzzle_themes
	)


## Convert to dictionary for serialization.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"fen": fen,
		"moves": " ".join(solution_moves),
		"rating": rating,
		"mate_in": mate_in,
		"themes": " ".join(themes)
	}
