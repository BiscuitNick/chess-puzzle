class_name ChessLogic
extends Node
## Chess logic autoload singleton for board state representation and FEN parsing.
## Provides core chess data structures and notation conversion utilities.

# Piece type enumeration
enum PieceType { NONE, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }

# Piece color enumeration
enum PieceColor { WHITE, BLACK }

# Piece constants - white pieces are 1-6, black pieces are 9-14
# The gap allows using piece & 8 to check color (0 = white, 8 = black)
const EMPTY = 0
const W_PAWN = 1
const W_KNIGHT = 2
const W_BISHOP = 3
const W_ROOK = 4
const W_QUEEN = 5
const W_KING = 6
const B_PAWN = 9
const B_KNIGHT = 10
const B_BISHOP = 11
const B_ROOK = 12
const B_QUEEN = 13
const B_KING = 14

# Castling rights bitmask constants
const CASTLE_K = 1  # White kingside
const CASTLE_Q = 2  # White queenside
const CASTLE_k = 4  # Black kingside
const CASTLE_q = 8  # Black queenside

# FEN character to piece constant mapping
const FEN_TO_PIECE = {
	'P': W_PAWN, 'N': W_KNIGHT, 'B': W_BISHOP, 'R': W_ROOK, 'Q': W_QUEEN, 'K': W_KING,
	'p': B_PAWN, 'n': B_KNIGHT, 'b': B_BISHOP, 'r': B_ROOK, 'q': B_QUEEN, 'k': B_KING
}

# Piece constant to FEN character mapping
const PIECE_TO_FEN = {
	W_PAWN: 'P', W_KNIGHT: 'N', W_BISHOP: 'B', W_ROOK: 'R', W_QUEEN: 'Q', W_KING: 'K',
	B_PAWN: 'p', B_KNIGHT: 'n', B_BISHOP: 'b', B_ROOK: 'r', B_QUEEN: 'q', B_KING: 'k'
}

# Starting position FEN
const STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

# Board state - 64 squares, index 0 = a8, index 63 = h1
# Layout: ranks 8-1 (top to bottom), files a-h (left to right)
var board: Array[int] = []

# Game state
var side_to_move: PieceColor = PieceColor.WHITE
var castling_rights: int = 0  # Bitmask: K=1, Q=2, k=4, q=8
var en_passant_square: int = -1  # -1 if none, otherwise board index
var halfmove_clock: int = 0  # Moves since pawn push or capture (50-move rule)
var fullmove_number: int = 1  # Incremented after Black's move

# King position cache for efficient check detection
var _white_king_square: int = -1
var _black_king_square: int = -1


func _ready() -> void:
	# Initialize board with 64 empty squares
	board.resize(64)
	board.fill(EMPTY)
	# Load starting position
	parse_fen(STARTING_FEN)


## Convert algebraic notation (e.g., "e4") to board index (0-63).
## a8=0, h8=7, a1=56, h1=63
func algebraic_to_index(square: String) -> int:
	if square.length() != 2:
		return -1
	var file = square[0].to_lower().unicode_at(0) - "a".unicode_at(0)  # 0-7
	var rank = int(square[1]) - 1  # 0-7 (rank 1=0, rank 8=7)
	if file < 0 or file > 7 or rank < 0 or rank > 7:
		return -1
	# Convert to index: rank 8 is at the top (indices 0-7), rank 1 is at bottom (indices 56-63)
	return (7 - rank) * 8 + file


## Convert board index (0-63) to algebraic notation (e.g., "e4").
func index_to_algebraic(index: int) -> String:
	if index < 0 or index > 63:
		return ""
	var file = index % 8
	var rank = 7 - (index / 8)
	return char("a".unicode_at(0) + file) + str(rank + 1)


## Get piece at the given square index.
func get_piece(square: int) -> int:
	if square < 0 or square > 63:
		return EMPTY
	return board[square]


## Check if a piece is white (returns false for EMPTY).
func is_white_piece(piece: int) -> bool:
	return piece >= W_PAWN and piece <= W_KING


## Check if a piece is black (returns false for EMPTY).
func is_black_piece(piece: int) -> bool:
	return piece >= B_PAWN and piece <= B_KING


## Get the color of a piece (-1 for EMPTY).
func get_piece_color(piece: int) -> int:
	if is_white_piece(piece):
		return PieceColor.WHITE
	elif is_black_piece(piece):
		return PieceColor.BLACK
	return -1


## Get the type of a piece (strips color).
func get_piece_type(piece: int) -> int:
	if piece == EMPTY:
		return PieceType.NONE
	# White pieces are 1-6, black pieces are 9-14
	# Subtracting 8 from black pieces gives 1-6
	var type_val = piece if piece <= 6 else piece - 8
	return type_val  # Maps to PieceType enum


## Parse a FEN string and set up the board state.
func parse_fen(fen: String) -> void:
	var fields = fen.strip_edges().split(" ")
	if fields.size() < 4:
		push_error("Invalid FEN: not enough fields")
		return

	# Reset board
	board.fill(EMPTY)
	_white_king_square = -1
	_black_king_square = -1

	# Field 0: Piece placement
	var ranks = fields[0].split("/")
	if ranks.size() != 8:
		push_error("Invalid FEN: piece placement must have 8 ranks")
		return

	var square = 0
	for rank in ranks:
		for c in rank:
			if c.is_valid_int():
				# Skip empty squares
				square += int(c)
			elif FEN_TO_PIECE.has(c):
				var piece = FEN_TO_PIECE[c]
				board[square] = piece
				# Track king positions
				if piece == W_KING:
					_white_king_square = square
				elif piece == B_KING:
					_black_king_square = square
				square += 1
			else:
				push_error("Invalid FEN: unknown piece character '%s'" % c)
				return

	# Field 1: Side to move
	if fields.size() > 1:
		side_to_move = PieceColor.WHITE if fields[1] == "w" else PieceColor.BLACK

	# Field 2: Castling rights
	castling_rights = 0
	if fields.size() > 2 and fields[2] != "-":
		for c in fields[2]:
			match c:
				'K': castling_rights |= CASTLE_K
				'Q': castling_rights |= CASTLE_Q
				'k': castling_rights |= CASTLE_k
				'q': castling_rights |= CASTLE_q

	# Field 3: En passant square
	en_passant_square = -1
	if fields.size() > 3 and fields[3] != "-":
		en_passant_square = algebraic_to_index(fields[3])

	# Field 4: Halfmove clock
	halfmove_clock = 0
	if fields.size() > 4:
		halfmove_clock = int(fields[4])

	# Field 5: Fullmove number
	fullmove_number = 1
	if fields.size() > 5:
		fullmove_number = int(fields[5])


## Convert current board state to FEN string.
func to_fen() -> String:
	var fen_parts: Array[String] = []

	# Piece placement
	var placement_parts: Array[String] = []
	for rank in range(8):
		var rank_str = ""
		var empty_count = 0
		for file in range(8):
			var piece = board[rank * 8 + file]
			if piece == EMPTY:
				empty_count += 1
			else:
				if empty_count > 0:
					rank_str += str(empty_count)
					empty_count = 0
				rank_str += PIECE_TO_FEN.get(piece, "?")
		if empty_count > 0:
			rank_str += str(empty_count)
		placement_parts.append(rank_str)
	fen_parts.append("/".join(placement_parts))

	# Side to move
	fen_parts.append("w" if side_to_move == PieceColor.WHITE else "b")

	# Castling rights
	var castling_str = ""
	if castling_rights & CASTLE_K: castling_str += "K"
	if castling_rights & CASTLE_Q: castling_str += "Q"
	if castling_rights & CASTLE_k: castling_str += "k"
	if castling_rights & CASTLE_q: castling_str += "q"
	fen_parts.append(castling_str if castling_str else "-")

	# En passant square
	fen_parts.append(index_to_algebraic(en_passant_square) if en_passant_square >= 0 else "-")

	# Halfmove clock and fullmove number
	fen_parts.append(str(halfmove_clock))
	fen_parts.append(str(fullmove_number))

	return " ".join(fen_parts)


## Convert UCI move notation (e.g., "e2e4", "e7e8q") to move data.
## Returns Dictionary with 'from', 'to', and 'promotion' keys.
func uci_to_squares(uci: String) -> Dictionary:
	var result = {
		"from": -1,
		"to": -1,
		"promotion": EMPTY
	}

	if uci.length() < 4:
		return result

	# Parse source and destination squares
	var from_square = uci.substr(0, 2)
	var to_square = uci.substr(2, 2)

	result["from"] = algebraic_to_index(from_square)
	result["to"] = algebraic_to_index(to_square)

	# Check for promotion piece (5th character)
	if uci.length() >= 5:
		var promo_char = uci[4].to_lower()
		# Determine piece color based on destination rank
		var dest_rank = result["to"] / 8
		var is_white_promotion = (dest_rank == 0)  # Rank 8
		match promo_char:
			'q': result["promotion"] = W_QUEEN if is_white_promotion else B_QUEEN
			'r': result["promotion"] = W_ROOK if is_white_promotion else B_ROOK
			'b': result["promotion"] = W_BISHOP if is_white_promotion else B_BISHOP
			'n': result["promotion"] = W_KNIGHT if is_white_promotion else B_KNIGHT

	return result


## Convert square indices to UCI move notation.
func squares_to_uci(from: int, to: int, promotion: int = EMPTY) -> String:
	var uci = index_to_algebraic(from) + index_to_algebraic(to)

	# Add promotion piece if applicable
	if promotion != EMPTY:
		var promo_type = get_piece_type(promotion)
		match promo_type:
			PieceType.QUEEN: uci += "q"
			PieceType.ROOK: uci += "r"
			PieceType.BISHOP: uci += "b"
			PieceType.KNIGHT: uci += "n"

	return uci


## Get the file (0-7, a-h) of a square index.
func get_file(square: int) -> int:
	return square % 8


## Get the rank (0-7, 8-1 from top) of a square index.
func get_rank(square: int) -> int:
	return square / 8


## Get king position for the given color.
func get_king_square(color: PieceColor) -> int:
	return _white_king_square if color == PieceColor.WHITE else _black_king_square


## Create a copy of the current board state.
func copy_board_state() -> Dictionary:
	return {
		"board": board.duplicate(),
		"side_to_move": side_to_move,
		"castling_rights": castling_rights,
		"en_passant_square": en_passant_square,
		"halfmove_clock": halfmove_clock,
		"fullmove_number": fullmove_number,
		"_white_king_square": _white_king_square,
		"_black_king_square": _black_king_square
	}


## Restore board state from a saved copy.
func restore_board_state(state: Dictionary) -> void:
	board = state["board"].duplicate()
	side_to_move = state["side_to_move"]
	castling_rights = state["castling_rights"]
	en_passant_square = state["en_passant_square"]
	halfmove_clock = state["halfmove_clock"]
	fullmove_number = state["fullmove_number"]
	_white_king_square = state["_white_king_square"]
	_black_king_square = state["_black_king_square"]
