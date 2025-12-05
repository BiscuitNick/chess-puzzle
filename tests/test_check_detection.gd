extends GutTest
## Tests for check detection in ChessLogic.

const ChessLogicScript = preload("res://scripts/autoload/chess_logic.gd")

var chess_logic


func before_each() -> void:
	chess_logic = ChessLogicScript.new()
	add_child(chess_logic)
	chess_logic._ready()


func after_each() -> void:
	chess_logic.queue_free()


# =============================================================================
# BASIC CHECK DETECTION
# =============================================================================

func test_starting_position_not_in_check() -> void:
	# Starting position, neither king in check
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.WHITE), "White not in check in starting position")
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black not in check in starting position")


func test_rook_gives_check() -> void:
	chess_logic.parse_fen("4k3/8/8/8/8/8/8/4R2K w - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check from rook")
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.WHITE), "White king not in check")


func test_bishop_gives_check() -> void:
	# Bishop on b5 attacks king on e8 along diagonal
	chess_logic.parse_fen("4k3/8/8/1B6/8/8/8/4K3 w - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check from bishop")


func test_queen_gives_check_diagonal() -> void:
	chess_logic.parse_fen("4k3/8/8/8/Q7/8/8/4K3 w - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check from queen (diagonal)")


func test_queen_gives_check_file() -> void:
	chess_logic.parse_fen("4k3/8/8/8/4Q3/8/8/4K3 w - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check from queen (file)")


func test_knight_gives_check() -> void:
	chess_logic.parse_fen("4k3/8/3N4/8/8/8/8/4K3 w - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check from knight")


func test_pawn_gives_check() -> void:
	chess_logic.parse_fen("4k3/3P4/8/8/8/8/8/4K3 w - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check from pawn")


func test_black_pawn_gives_check() -> void:
	chess_logic.parse_fen("4k3/8/8/8/8/5p2/4K3/8 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.WHITE), "White king in check from black pawn")


# =============================================================================
# BLOCKED ATTACKS
# =============================================================================

func test_rook_blocked_no_check() -> void:
	chess_logic.parse_fen("4k3/8/8/8/4p3/8/8/4R2K w - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king not in check (rook blocked)")


func test_bishop_blocked_no_check() -> void:
	chess_logic.parse_fen("4k3/8/8/3p4/8/2B5/8/4K3 w - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king not in check (bishop blocked)")


func test_queen_blocked_no_check() -> void:
	chess_logic.parse_fen("4k3/8/8/4p3/8/8/8/4Q2K w - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king not in check (queen blocked)")


# =============================================================================
# SQUARE ATTACK DETECTION
# =============================================================================

func test_square_attacked_by_rook() -> void:
	chess_logic.parse_fen("8/8/8/8/4R3/8/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	# All squares on e-file and 4th rank should be attacked
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("e1"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("e8"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("a4"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("h4"), ChessLogicScript.PieceColor.WHITE))
	# Diagonal should not be attacked
	assert_false(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("d3"), ChessLogicScript.PieceColor.WHITE))


func test_square_attacked_by_knight() -> void:
	chess_logic.parse_fen("8/8/8/8/4N3/8/8/8 w - - 0 1")
	# Knight on e4 attacks these squares
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("d2"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("f2"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("c3"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("g3"), ChessLogicScript.PieceColor.WHITE))
	# Adjacent squares not attacked by knight
	assert_false(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("e5"), ChessLogicScript.PieceColor.WHITE))
	assert_false(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("d4"), ChessLogicScript.PieceColor.WHITE))


func test_square_attacked_by_pawn() -> void:
	chess_logic.parse_fen("8/8/8/8/4P3/8/8/8 w - - 0 1")
	# White pawn on e4 attacks d5 and f5
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("d5"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("f5"), ChessLogicScript.PieceColor.WHITE))
	# Pawn does not attack squares in front or behind
	assert_false(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("e5"), ChessLogicScript.PieceColor.WHITE))
	assert_false(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("e3"), ChessLogicScript.PieceColor.WHITE))


func test_square_attacked_by_king() -> void:
	chess_logic.parse_fen("8/8/8/8/4K3/8/8/8 w - - 0 1")
	# King attacks all adjacent squares
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("d3"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("e3"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("f3"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("d4"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("f4"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("d5"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("e5"), ChessLogicScript.PieceColor.WHITE))
	assert_true(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("f5"), ChessLogicScript.PieceColor.WHITE))
	# Non-adjacent not attacked
	assert_false(chess_logic.is_square_attacked(chess_logic.algebraic_to_index("e6"), ChessLogicScript.PieceColor.WHITE))


# =============================================================================
# PIN DETECTION (via legal moves)
# =============================================================================

func test_pinned_piece_limited_moves() -> void:
	# White rook on e2 is pinned by black rook on e8
	chess_logic.parse_fen("4r3/8/8/8/8/8/4R3/4K3 w - - 0 1")
	var e2 = chess_logic.algebraic_to_index("e2")
	var legal_moves = chess_logic.get_legal_moves(e2)
	# Rook should only be able to move along e-file (including capture)
	for move in legal_moves:
		var move_file = chess_logic.get_file(move)
		assert_eq(move_file, 4, "Pinned rook can only move on e-file")


func test_pinned_bishop_on_diagonal() -> void:
	# White bishop on d2 is pinned by black bishop on a5 (diagonal to white king on e1)
	chess_logic.parse_fen("8/8/8/b7/8/8/3B4/4K3 w - - 0 1")
	var d2 = chess_logic.algebraic_to_index("d2")
	var legal_moves = chess_logic.get_legal_moves(d2)
	# Bishop should only be able to move along the a5-e1 diagonal
	var valid_squares = ["c3", "b4", "a5"]  # Can block or capture
	for move in legal_moves:
		var move_alg = chess_logic.index_to_algebraic(move)
		assert_true(move_alg in valid_squares, "Pinned bishop should only move along pin line: %s" % move_alg)


# =============================================================================
# DISCOVERED CHECK (via legal moves)
# =============================================================================

func test_discovered_check_position() -> void:
	# Moving the knight exposes king to check from rook
	chess_logic.parse_fen("4k3/8/8/8/8/8/4N3/r3K3 w - - 0 1")
	# White king is already in check from rook
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.WHITE))
