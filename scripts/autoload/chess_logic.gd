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


# =============================================================================
# MOVE GENERATION
# =============================================================================

# Direction offsets for move generation (index-based)
const DIR_N = -8   # North (toward rank 8)
const DIR_S = 8    # South (toward rank 1)
const DIR_E = 1    # East (toward h-file)
const DIR_W = -1   # West (toward a-file)
const DIR_NE = -7  # North-East
const DIR_NW = -9  # North-West
const DIR_SE = 9   # South-East
const DIR_SW = 7   # South-West

# Knight move offsets
const KNIGHT_OFFSETS = [-17, -15, -10, -6, 6, 10, 15, 17]

# All 8 directions for king and ray casting
const ALL_DIRECTIONS = [DIR_N, DIR_S, DIR_E, DIR_W, DIR_NE, DIR_NW, DIR_SE, DIR_SW]
const DIAGONAL_DIRECTIONS = [DIR_NE, DIR_NW, DIR_SE, DIR_SW]
const ORTHOGONAL_DIRECTIONS = [DIR_N, DIR_S, DIR_E, DIR_W]


## Check if a piece belongs to the given color.
func _is_piece_color(piece: int, color: PieceColor) -> bool:
	if color == PieceColor.WHITE:
		return is_white_piece(piece)
	return is_black_piece(piece)


## Check if a piece is an enemy piece (opposite color).
func _is_enemy_piece(piece: int, my_color: PieceColor) -> bool:
	if piece == EMPTY:
		return false
	if my_color == PieceColor.WHITE:
		return is_black_piece(piece)
	return is_white_piece(piece)


## Get pawn moves (single push, double push, diagonal captures, en passant).
func get_pawn_moves(square: int, color: PieceColor) -> Array[int]:
	var moves: Array[int] = []
	var file = get_file(square)
	var rank = get_rank(square)

	# Direction depends on color (white moves up/negative, black moves down/positive)
	var direction = DIR_N if color == PieceColor.WHITE else DIR_S
	var start_rank = 6 if color == PieceColor.WHITE else 1  # Rank 2 for white, rank 7 for black
	var promo_rank = 0 if color == PieceColor.WHITE else 7  # Rank 8 for white, rank 1 for black

	# Single push
	var single_target = square + direction
	if single_target >= 0 and single_target < 64 and board[single_target] == EMPTY:
		moves.append(single_target)

		# Double push from starting rank
		if rank == start_rank:
			var double_target = square + direction * 2
			if board[double_target] == EMPTY:
				moves.append(double_target)

	# Diagonal captures
	var capture_dirs = [direction + DIR_W, direction + DIR_E]
	for cap_dir in capture_dirs:
		var target = square + cap_dir
		if target < 0 or target > 63:
			continue

		# Check file wrapping (pawn can't capture across board edges)
		var target_file = get_file(target)
		if abs(target_file - file) != 1:
			continue

		# Regular capture
		if _is_enemy_piece(board[target], color):
			moves.append(target)

		# En passant capture
		if target == en_passant_square:
			moves.append(target)

	return moves


## Get knight moves (L-shaped).
func get_knight_moves(square: int, color: PieceColor) -> Array[int]:
	var moves: Array[int] = []
	var file = get_file(square)
	var rank = get_rank(square)

	for offset in KNIGHT_OFFSETS:
		var target = square + offset
		if target < 0 or target > 63:
			continue

		var target_file = get_file(target)
		var target_rank = get_rank(target)

		# Knight moves change file by 1-2 and rank by 1-2, total change must be 3
		var file_diff = abs(target_file - file)
		var rank_diff = abs(target_rank - rank)
		if (file_diff == 1 and rank_diff == 2) or (file_diff == 2 and rank_diff == 1):
			var target_piece = board[target]
			if target_piece == EMPTY or _is_enemy_piece(target_piece, color):
				moves.append(target)

	return moves


## Get moves along a ray (for sliding pieces).
func _get_ray_moves(square: int, direction: int, color: PieceColor) -> Array[int]:
	var moves: Array[int] = []
	var start_file = get_file(square)
	var prev_file = start_file
	var current = square + direction

	while current >= 0 and current < 64:
		var current_file = get_file(current)

		# Check for file wrapping: file should change by at most 1 per step for diagonals
		# For horizontal moves, file changes by 1 per step
		# For vertical moves, file doesn't change
		if direction == DIR_N or direction == DIR_S:
			# Vertical: file should not change
			if current_file != start_file:
				break
		elif direction == DIR_E or direction == DIR_W:
			# Horizontal: file should change by exactly 1 from previous
			if abs(current_file - prev_file) != 1:
				break
		else:
			# Diagonal: file should change by exactly 1 from previous
			if abs(current_file - prev_file) != 1:
				break

		var target_piece = board[current]
		if target_piece == EMPTY:
			moves.append(current)
		elif _is_enemy_piece(target_piece, color):
			moves.append(current)
			break  # Can capture but not go further
		else:
			break  # Blocked by friendly piece

		prev_file = current_file
		current += direction

	return moves


## Get bishop moves (diagonal rays).
func get_bishop_moves(square: int, color: PieceColor) -> Array[int]:
	var moves: Array[int] = []
	for direction in DIAGONAL_DIRECTIONS:
		moves.append_array(_get_ray_moves(square, direction, color))
	return moves


## Get rook moves (orthogonal rays).
func get_rook_moves(square: int, color: PieceColor) -> Array[int]:
	var moves: Array[int] = []
	for direction in ORTHOGONAL_DIRECTIONS:
		moves.append_array(_get_ray_moves(square, direction, color))
	return moves


## Get queen moves (combination of bishop and rook).
func get_queen_moves(square: int, color: PieceColor) -> Array[int]:
	var moves: Array[int] = []
	for direction in ALL_DIRECTIONS:
		moves.append_array(_get_ray_moves(square, direction, color))
	return moves


## Get king moves (one square in any direction, plus castling).
func get_king_moves(square: int, color: PieceColor) -> Array[int]:
	var moves: Array[int] = []
	var file = get_file(square)

	for direction in ALL_DIRECTIONS:
		var target = square + direction
		if target < 0 or target > 63:
			continue

		var target_file = get_file(target)

		# Check for file wrapping
		if abs(target_file - file) > 1:
			continue

		var target_piece = board[target]
		if target_piece == EMPTY or _is_enemy_piece(target_piece, color):
			moves.append(target)

	# Add castling moves (validation done in can_castle functions)
	if can_castle_kingside(color):
		# Kingside castle target: g1 for white (62), g8 for black (6)
		moves.append(60 + 2 if color == PieceColor.WHITE else 4 + 2)
	if can_castle_queenside(color):
		# Queenside castle target: c1 for white (58), c8 for black (2)
		moves.append(60 - 2 if color == PieceColor.WHITE else 4 - 2)

	return moves


## Check if the given color can castle kingside.
func can_castle_kingside(color: PieceColor) -> bool:
	# Check castling rights
	var right = CASTLE_K if color == PieceColor.WHITE else CASTLE_k
	if (castling_rights & right) == 0:
		return false

	# Get square indices
	var king_sq = 60 if color == PieceColor.WHITE else 4   # e1 or e8
	var rook_sq = 63 if color == PieceColor.WHITE else 7   # h1 or h8
	var f_sq = 61 if color == PieceColor.WHITE else 5      # f1 or f8
	var g_sq = 62 if color == PieceColor.WHITE else 6      # g1 or g8

	# Verify king is on starting square
	var king = W_KING if color == PieceColor.WHITE else B_KING
	if board[king_sq] != king:
		return false

	# Verify rook is on starting square
	var rook = W_ROOK if color == PieceColor.WHITE else B_ROOK
	if board[rook_sq] != rook:
		return false

	# Verify squares between king and rook are empty
	if board[f_sq] != EMPTY or board[g_sq] != EMPTY:
		return false

	# Verify king is not in check
	var enemy_color = PieceColor.BLACK if color == PieceColor.WHITE else PieceColor.WHITE
	if is_square_attacked(king_sq, enemy_color):
		return false

	# Verify king doesn't pass through or land on attacked squares
	if is_square_attacked(f_sq, enemy_color):
		return false
	if is_square_attacked(g_sq, enemy_color):
		return false

	return true


## Check if the given color can castle queenside.
func can_castle_queenside(color: PieceColor) -> bool:
	# Check castling rights
	var right = CASTLE_Q if color == PieceColor.WHITE else CASTLE_q
	if (castling_rights & right) == 0:
		return false

	# Get square indices
	var king_sq = 60 if color == PieceColor.WHITE else 4   # e1 or e8
	var rook_sq = 56 if color == PieceColor.WHITE else 0   # a1 or a8
	var b_sq = 57 if color == PieceColor.WHITE else 1      # b1 or b8
	var c_sq = 58 if color == PieceColor.WHITE else 2      # c1 or c8
	var d_sq = 59 if color == PieceColor.WHITE else 3      # d1 or d8

	# Verify king is on starting square
	var king = W_KING if color == PieceColor.WHITE else B_KING
	if board[king_sq] != king:
		return false

	# Verify rook is on starting square
	var rook = W_ROOK if color == PieceColor.WHITE else B_ROOK
	if board[rook_sq] != rook:
		return false

	# Verify squares between king and rook are empty
	if board[b_sq] != EMPTY or board[c_sq] != EMPTY or board[d_sq] != EMPTY:
		return false

	# Verify king is not in check
	var enemy_color = PieceColor.BLACK if color == PieceColor.WHITE else PieceColor.WHITE
	if is_square_attacked(king_sq, enemy_color):
		return false

	# Verify king doesn't pass through or land on attacked squares (d and c)
	if is_square_attacked(d_sq, enemy_color):
		return false
	if is_square_attacked(c_sq, enemy_color):
		return false

	return true


## Get pseudo-legal moves for a piece (doesn't check if move leaves king in check).
func get_pseudo_legal_moves(square: int) -> Array[int]:
	var piece = board[square]
	if piece == EMPTY:
		return []

	var color = get_piece_color(piece)
	var piece_type = get_piece_type(piece)

	match piece_type:
		PieceType.PAWN:
			return get_pawn_moves(square, color)
		PieceType.KNIGHT:
			return get_knight_moves(square, color)
		PieceType.BISHOP:
			return get_bishop_moves(square, color)
		PieceType.ROOK:
			return get_rook_moves(square, color)
		PieceType.QUEEN:
			return get_queen_moves(square, color)
		PieceType.KING:
			return get_king_moves(square, color)

	return []


# =============================================================================
# ATTACK DETECTION
# =============================================================================

## Check if a square is attacked by any piece of the given color.
func is_square_attacked(square: int, by_color: PieceColor) -> bool:
	var file = get_file(square)
	var rank = get_rank(square)

	# Check pawn attacks
	var pawn_dir = DIR_S if by_color == PieceColor.WHITE else DIR_N  # Opposite direction
	var pawn = W_PAWN if by_color == PieceColor.WHITE else B_PAWN
	for cap_offset in [pawn_dir + DIR_W, pawn_dir + DIR_E]:
		var attacker_sq = square + cap_offset
		if attacker_sq >= 0 and attacker_sq < 64:
			var attacker_file = get_file(attacker_sq)
			if abs(attacker_file - file) == 1 and board[attacker_sq] == pawn:
				return true

	# Check knight attacks
	var knight = W_KNIGHT if by_color == PieceColor.WHITE else B_KNIGHT
	for offset in KNIGHT_OFFSETS:
		var attacker_sq = square + offset
		if attacker_sq >= 0 and attacker_sq < 64:
			var attacker_file = get_file(attacker_sq)
			var file_diff = abs(attacker_file - file)
			var rank_diff = abs(get_rank(attacker_sq) - rank)
			if (file_diff == 1 and rank_diff == 2) or (file_diff == 2 and rank_diff == 1):
				if board[attacker_sq] == knight:
					return true

	# Check king attacks
	var king = W_KING if by_color == PieceColor.WHITE else B_KING
	for direction in ALL_DIRECTIONS:
		var attacker_sq = square + direction
		if attacker_sq >= 0 and attacker_sq < 64:
			var attacker_file = get_file(attacker_sq)
			if abs(attacker_file - file) <= 1 and board[attacker_sq] == king:
				return true

	# Check sliding piece attacks (bishop, rook, queen)
	var bishop = W_BISHOP if by_color == PieceColor.WHITE else B_BISHOP
	var rook = W_ROOK if by_color == PieceColor.WHITE else B_ROOK
	var queen = W_QUEEN if by_color == PieceColor.WHITE else B_QUEEN

	# Diagonal rays (bishop/queen)
	for direction in DIAGONAL_DIRECTIONS:
		var current = square + direction
		var current_file = file
		while current >= 0 and current < 64:
			var new_file = get_file(current)
			if abs(new_file - current_file) != 1:
				break
			var piece = board[current]
			if piece != EMPTY:
				if piece == bishop or piece == queen:
					return true
				break  # Blocked by another piece
			current_file = new_file
			current += direction

	# Orthogonal rays (rook/queen)
	for direction in ORTHOGONAL_DIRECTIONS:
		var current = square + direction
		var current_file = file
		while current >= 0 and current < 64:
			var new_file = get_file(current)
			# Check file wrapping for horizontal moves
			if direction == DIR_E or direction == DIR_W:
				if abs(new_file - current_file) != 1:
					break
			var piece = board[current]
			if piece != EMPTY:
				if piece == rook or piece == queen:
					return true
				break  # Blocked by another piece
			current_file = new_file
			current += direction

	return false


## Check if the given color's king is in check.
func is_in_check(color: PieceColor = side_to_move) -> bool:
	var king_square = get_king_square(color)
	if king_square < 0:
		return false  # King not found (shouldn't happen in valid position)
	var enemy_color = PieceColor.BLACK if color == PieceColor.WHITE else PieceColor.WHITE
	return is_square_attacked(king_square, enemy_color)


# =============================================================================
# LEGAL MOVE GENERATION
# =============================================================================

## Get all legal moves for a piece at the given square.
func get_legal_moves(square: int) -> Array[int]:
	var piece = board[square]
	if piece == EMPTY:
		return []

	var color = get_piece_color(piece)
	if color != side_to_move:
		return []  # Not this player's piece

	var pseudo_moves = get_pseudo_legal_moves(square)
	var legal_moves: Array[int] = []

	# Test each pseudo-legal move
	var saved_state = copy_board_state()

	for target in pseudo_moves:
		# Make the move temporarily
		_make_move_unchecked(square, target)

		# Check if our king is in check after the move
		if not is_in_check(color):
			legal_moves.append(target)

		# Restore state
		restore_board_state(saved_state)

	return legal_moves


## Check if a specific move is legal.
func is_move_legal(from: int, to: int) -> bool:
	var legal_moves = get_legal_moves(from)
	return to in legal_moves


## Make a move without checking legality (internal use).
func _make_move_unchecked(from: int, to: int, promotion: int = EMPTY) -> void:
	var piece = board[from]
	var color = get_piece_color(piece)
	var piece_type = get_piece_type(piece)
	var captured = board[to]

	# Handle castling
	if piece_type == PieceType.KING and abs(to - from) == 2:
		# This is a castling move
		var is_kingside = to > from
		var rook_from: int
		var rook_to: int
		var rook = W_ROOK if color == PieceColor.WHITE else B_ROOK

		if color == PieceColor.WHITE:
			if is_kingside:
				rook_from = 63  # h1
				rook_to = 61    # f1
			else:
				rook_from = 56  # a1
				rook_to = 59    # d1
		else:
			if is_kingside:
				rook_from = 7   # h8
				rook_to = 5     # f8
			else:
				rook_from = 0   # a8
				rook_to = 3     # d8

		# Move the rook
		board[rook_from] = EMPTY
		board[rook_to] = rook

	# Handle en passant capture
	if piece_type == PieceType.PAWN and to == en_passant_square:
		var captured_pawn_sq = to + (DIR_S if color == PieceColor.WHITE else DIR_N)
		board[captured_pawn_sq] = EMPTY

	# Move the piece
	board[from] = EMPTY
	board[to] = piece

	# Handle pawn promotion
	if piece_type == PieceType.PAWN:
		var promo_rank = 0 if color == PieceColor.WHITE else 7
		if get_rank(to) == promo_rank:
			if promotion != EMPTY:
				board[to] = promotion
			else:
				# Default to queen
				board[to] = W_QUEEN if color == PieceColor.WHITE else B_QUEEN

	# Update king position
	if piece == W_KING:
		_white_king_square = to
	elif piece == B_KING:
		_black_king_square = to


## Make a move (validates legality first).
func make_move(from: int, to: int, promotion: int = EMPTY) -> bool:
	if not is_move_legal(from, to):
		return false

	var piece = board[from]
	var color = get_piece_color(piece)
	var piece_type = get_piece_type(piece)
	var captured = board[to]

	# Store en passant state before clearing
	var old_en_passant = en_passant_square

	# Clear en passant
	en_passant_square = -1

	# Handle castling
	if piece_type == PieceType.KING and abs(to - from) == 2:
		# This is a castling move
		var is_kingside = to > from
		var rook_from: int
		var rook_to: int
		var rook = W_ROOK if color == PieceColor.WHITE else B_ROOK

		if color == PieceColor.WHITE:
			if is_kingside:
				rook_from = 63  # h1
				rook_to = 61    # f1
			else:
				rook_from = 56  # a1
				rook_to = 59    # d1
		else:
			if is_kingside:
				rook_from = 7   # h8
				rook_to = 5     # f8
			else:
				rook_from = 0   # a8
				rook_to = 3     # d8

		# Move the rook
		board[rook_from] = EMPTY
		board[rook_to] = rook

	# Handle en passant capture
	if piece_type == PieceType.PAWN and to == old_en_passant:
		var captured_pawn_sq = to + (DIR_S if color == PieceColor.WHITE else DIR_N)
		board[captured_pawn_sq] = EMPTY
		captured = W_PAWN if color == PieceColor.BLACK else B_PAWN  # For halfmove clock

	# Set new en passant square for double pawn push
	if piece_type == PieceType.PAWN:
		var move_dist = abs(to - from)
		if move_dist == 16:  # Double push
			en_passant_square = from + (DIR_N if color == PieceColor.WHITE else DIR_S)

	# Move the piece
	board[from] = EMPTY
	board[to] = piece

	# Handle pawn promotion
	if piece_type == PieceType.PAWN:
		var promo_rank = 0 if color == PieceColor.WHITE else 7
		if get_rank(to) == promo_rank:
			if promotion != EMPTY:
				board[to] = promotion
			else:
				board[to] = W_QUEEN if color == PieceColor.WHITE else B_QUEEN

	# Update king position
	if piece == W_KING:
		_white_king_square = to
		# Remove castling rights
		castling_rights &= ~(CASTLE_K | CASTLE_Q)
	elif piece == B_KING:
		_black_king_square = to
		castling_rights &= ~(CASTLE_k | CASTLE_q)

	# Update castling rights if rook moves or is captured
	if piece_type == PieceType.ROOK:
		if from == 63:  # h1
			castling_rights &= ~CASTLE_K
		elif from == 56:  # a1
			castling_rights &= ~CASTLE_Q
		elif from == 7:  # h8
			castling_rights &= ~CASTLE_k
		elif from == 0:  # a8
			castling_rights &= ~CASTLE_q

	if to == 63:  # h1 captured
		castling_rights &= ~CASTLE_K
	elif to == 56:  # a1 captured
		castling_rights &= ~CASTLE_Q
	elif to == 7:  # h8 captured
		castling_rights &= ~CASTLE_k
	elif to == 0:  # a8 captured
		castling_rights &= ~CASTLE_q

	# Update halfmove clock
	if piece_type == PieceType.PAWN or captured != EMPTY:
		halfmove_clock = 0
	else:
		halfmove_clock += 1

	# Update fullmove number
	if color == PieceColor.BLACK:
		fullmove_number += 1

	# Switch side to move
	side_to_move = PieceColor.BLACK if color == PieceColor.WHITE else PieceColor.WHITE

	return true


# =============================================================================
# GAME STATE DETECTION
# =============================================================================

## Check if the current side to move has any legal moves.
func has_legal_moves() -> bool:
	for square in range(64):
		var piece = board[square]
		if piece != EMPTY and _is_piece_color(piece, side_to_move):
			if get_legal_moves(square).size() > 0:
				return true
	return false


## Check if the current position is checkmate for the given color.
## If no color is specified, checks the side_to_move.
func is_checkmate(color: PieceColor = side_to_move) -> bool:
	# Temporarily set side_to_move to check the specified color
	var original_side = side_to_move
	side_to_move = color
	var result = is_in_check() and not has_legal_moves()
	side_to_move = original_side
	return result


## Check if the current position is stalemate for the given color.
## If no color is specified, checks the side_to_move.
func is_stalemate(color: PieceColor = side_to_move) -> bool:
	# Temporarily set side_to_move to check the specified color
	var original_side = side_to_move
	side_to_move = color
	var result = not is_in_check() and not has_legal_moves()
	side_to_move = original_side
	return result


## Get all legal moves for the current side.
func get_all_legal_moves() -> Dictionary:
	var all_moves: Dictionary = {}
	for square in range(64):
		var piece = board[square]
		if piece != EMPTY and _is_piece_color(piece, side_to_move):
			var moves = get_legal_moves(square)
			if moves.size() > 0:
				all_moves[square] = moves
	return all_moves
