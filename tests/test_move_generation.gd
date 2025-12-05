extends GutTest
## Tests for move generation in ChessLogic.

const ChessLogicScript = preload("res://scripts/autoload/chess_logic.gd")

var chess_logic


func before_each() -> void:
	chess_logic = ChessLogicScript.new()
	add_child(chess_logic)
	chess_logic._ready()


func after_each() -> void:
	chess_logic.queue_free()


# =============================================================================
# PAWN MOVE TESTS
# =============================================================================

func test_white_pawn_single_push() -> void:
	chess_logic.parse_fen("8/8/8/8/8/8/4P3/8 w - - 0 1")
	var e2 = chess_logic.algebraic_to_index("e2")
	var moves = chess_logic.get_pawn_moves(e2, ChessLogicScript.PieceColor.WHITE)
	assert_true(chess_logic.algebraic_to_index("e3") in moves, "Pawn should be able to push to e3")
	assert_true(chess_logic.algebraic_to_index("e4") in moves, "Pawn should be able to double push to e4")


func test_white_pawn_blocked() -> void:
	chess_logic.parse_fen("8/8/8/8/8/4p3/4P3/8 w - - 0 1")
	var e2 = chess_logic.algebraic_to_index("e2")
	var moves = chess_logic.get_pawn_moves(e2, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 0, "Blocked pawn should have no moves")


func test_white_pawn_double_push_blocked() -> void:
	chess_logic.parse_fen("8/8/8/8/4p3/8/4P3/8 w - - 0 1")
	var e2 = chess_logic.algebraic_to_index("e2")
	var moves = chess_logic.get_pawn_moves(e2, ChessLogicScript.PieceColor.WHITE)
	assert_true(chess_logic.algebraic_to_index("e3") in moves, "Pawn can push to e3")
	assert_false(chess_logic.algebraic_to_index("e4") in moves, "Pawn cannot double push when e4 blocked")


func test_white_pawn_captures() -> void:
	chess_logic.parse_fen("8/8/8/8/3p1p2/4P3/8/8 w - - 0 1")
	var e3 = chess_logic.algebraic_to_index("e3")
	var moves = chess_logic.get_pawn_moves(e3, ChessLogicScript.PieceColor.WHITE)
	assert_true(chess_logic.algebraic_to_index("d4") in moves, "Pawn can capture d4")
	assert_true(chess_logic.algebraic_to_index("f4") in moves, "Pawn can capture f4")
	assert_true(chess_logic.algebraic_to_index("e4") in moves, "Pawn can push to e4")


func test_black_pawn_moves() -> void:
	chess_logic.parse_fen("8/4p3/8/8/8/8/8/8 b - - 0 1")
	var e7 = chess_logic.algebraic_to_index("e7")
	var moves = chess_logic.get_pawn_moves(e7, ChessLogicScript.PieceColor.BLACK)
	assert_true(chess_logic.algebraic_to_index("e6") in moves, "Black pawn can push to e6")
	assert_true(chess_logic.algebraic_to_index("e5") in moves, "Black pawn can double push to e5")


func test_pawn_a_file_no_left_capture() -> void:
	chess_logic.parse_fen("8/8/8/8/8/p1p5/P7/8 w - - 0 1")
	var a2 = chess_logic.algebraic_to_index("a2")
	var moves = chess_logic.get_pawn_moves(a2, ChessLogicScript.PieceColor.WHITE)
	# Pawn on a-file cannot capture left (would wrap around board)
	assert_eq(moves.size(), 0, "a-file pawn blocked should have no moves")


func test_en_passant_capture() -> void:
	chess_logic.parse_fen("8/8/8/3pP3/8/8/8/8 w - d6 0 1")
	var e5 = chess_logic.algebraic_to_index("e5")
	var moves = chess_logic.get_pawn_moves(e5, ChessLogicScript.PieceColor.WHITE)
	assert_true(chess_logic.algebraic_to_index("d6") in moves, "Pawn can capture en passant on d6")
	assert_true(chess_logic.algebraic_to_index("e6") in moves, "Pawn can push to e6")


# =============================================================================
# KNIGHT MOVE TESTS
# =============================================================================

func test_knight_center_moves() -> void:
	chess_logic.parse_fen("8/8/8/8/4N3/8/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_knight_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 8, "Knight in center should have 8 moves")

	# Check all 8 target squares
	var expected = ["d2", "f2", "c3", "g3", "c5", "g5", "d6", "f6"]
	for sq in expected:
		assert_true(chess_logic.algebraic_to_index(sq) in moves, "Knight should be able to move to %s" % sq)


func test_knight_corner_moves() -> void:
	chess_logic.parse_fen("8/8/8/8/8/8/8/N7 w - - 0 1")
	var a1 = chess_logic.algebraic_to_index("a1")
	var moves = chess_logic.get_knight_moves(a1, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 2, "Knight in corner should have 2 moves")
	assert_true(chess_logic.algebraic_to_index("b3") in moves, "Knight should be able to move to b3")
	assert_true(chess_logic.algebraic_to_index("c2") in moves, "Knight should be able to move to c2")


func test_knight_cannot_capture_friendly() -> void:
	chess_logic.parse_fen("8/8/3P1P2/2P3P1/4N3/2P3P1/3P1P2/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_knight_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 0, "Knight cannot capture friendly pieces")


func test_knight_can_capture_enemy() -> void:
	chess_logic.parse_fen("8/8/3p1p2/8/4N3/8/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_knight_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_true(chess_logic.algebraic_to_index("d6") in moves, "Knight can capture d6")
	assert_true(chess_logic.algebraic_to_index("f6") in moves, "Knight can capture f6")


# =============================================================================
# SLIDING PIECE TESTS
# =============================================================================

func test_rook_empty_board() -> void:
	chess_logic.parse_fen("8/8/8/8/4R3/8/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_rook_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 14, "Rook in center on empty board should have 14 moves")


func test_rook_blocked_by_friendly() -> void:
	chess_logic.parse_fen("8/8/8/4P3/4R3/8/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_rook_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_false(chess_logic.algebraic_to_index("e5") in moves, "Rook blocked by pawn on e5")
	assert_false(chess_logic.algebraic_to_index("e6") in moves, "Rook cannot jump over pawn")


func test_rook_captures_enemy() -> void:
	chess_logic.parse_fen("8/8/8/4p3/4R3/8/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_rook_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_true(chess_logic.algebraic_to_index("e5") in moves, "Rook can capture e5")
	assert_false(chess_logic.algebraic_to_index("e6") in moves, "Rook cannot go past captured piece")


func test_bishop_empty_board() -> void:
	chess_logic.parse_fen("8/8/8/8/4B3/8/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_bishop_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 13, "Bishop on e4 on empty board should have 13 moves")


func test_queen_combines_rook_and_bishop() -> void:
	chess_logic.parse_fen("8/8/8/8/4Q3/8/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_queen_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 27, "Queen on e4 on empty board should have 27 moves (14 rook + 13 bishop)")


# =============================================================================
# KING MOVE TESTS
# =============================================================================

func test_king_center_moves() -> void:
	chess_logic.parse_fen("8/8/8/8/4K3/8/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_king_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 8, "King in center should have 8 moves")


func test_king_corner_moves() -> void:
	chess_logic.parse_fen("8/8/8/8/8/8/8/K7 w - - 0 1")
	var a1 = chess_logic.algebraic_to_index("a1")
	var moves = chess_logic.get_king_moves(a1, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 3, "King in corner should have 3 moves")


func test_king_cannot_capture_friendly() -> void:
	chess_logic.parse_fen("8/8/8/3PPP2/3PKP2/3PPP2/8/8 w - - 0 1")
	var e4 = chess_logic.algebraic_to_index("e4")
	var moves = chess_logic.get_king_moves(e4, ChessLogicScript.PieceColor.WHITE)
	assert_eq(moves.size(), 0, "King surrounded by friendly pieces has no moves")


# =============================================================================
# LEGAL MOVE FILTERING TESTS
# =============================================================================

func test_pinned_piece_cannot_move_off_pin_line() -> void:
	# White king on e1, white rook on e2, black rook on e8
	chess_logic.parse_fen("4r3/8/8/8/8/8/4R3/4K3 w - - 0 1")
	var e2 = chess_logic.algebraic_to_index("e2")
	var legal_moves = chess_logic.get_legal_moves(e2)
	# Rook is pinned, can only move along the e-file
	for move in legal_moves:
		assert_eq(chess_logic.get_file(move), chess_logic.get_file(e2), "Pinned rook can only move on e-file")


func test_king_cannot_move_into_check() -> void:
	chess_logic.parse_fen("8/8/8/8/4r3/8/8/4K3 w - - 0 1")
	var e1 = chess_logic.algebraic_to_index("e1")
	var legal_moves = chess_logic.get_legal_moves(e1)
	# Rook on e4 attacks e-file, so e2 is attacked
	assert_false(chess_logic.algebraic_to_index("e2") in legal_moves, "King cannot move to e2 (attacked by rook on e-file)")
	# f2 and d2 are NOT attacked by rook on e4 (rook only attacks orthogonally)
	assert_true(chess_logic.algebraic_to_index("f2") in legal_moves, "King can move to f2 (not attacked by rook)")
	assert_true(chess_logic.algebraic_to_index("d2") in legal_moves, "King can move to d2 (not attacked by rook)")


func test_must_block_or_capture_when_in_check() -> void:
	chess_logic.parse_fen("4r3/8/8/8/8/8/4R3/4K3 w - - 0 1")
	# White is in check from black rook on e8
	# White rook on e2 can block or capture
	var e2 = chess_logic.algebraic_to_index("e2")
	var legal_moves = chess_logic.get_legal_moves(e2)
	# The rook should be able to capture on e8 or block anywhere on e-file
	assert_true(chess_logic.algebraic_to_index("e8") in legal_moves, "Rook can capture attacker")


# =============================================================================
# MAKE MOVE TESTS
# =============================================================================

func test_make_move_updates_board() -> void:
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	var e2 = chess_logic.algebraic_to_index("e2")
	var e4 = chess_logic.algebraic_to_index("e4")
	chess_logic.make_move(e2, e4)
	assert_eq(chess_logic.board[e2], ChessLogic.EMPTY, "e2 should be empty after move")
	assert_eq(chess_logic.board[e4], ChessLogic.W_PAWN, "e4 should have white pawn")


func test_make_move_switches_side() -> void:
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	assert_eq(chess_logic.side_to_move, ChessLogicScript.PieceColor.WHITE)
	var e2 = chess_logic.algebraic_to_index("e2")
	var e4 = chess_logic.algebraic_to_index("e4")
	chess_logic.make_move(e2, e4)
	assert_eq(chess_logic.side_to_move, ChessLogicScript.PieceColor.BLACK)


func test_make_move_sets_en_passant() -> void:
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	var e2 = chess_logic.algebraic_to_index("e2")
	var e4 = chess_logic.algebraic_to_index("e4")
	chess_logic.make_move(e2, e4)
	assert_eq(chess_logic.en_passant_square, chess_logic.algebraic_to_index("e3"), "En passant should be set to e3")


func test_make_move_clears_en_passant() -> void:
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
	assert_eq(chess_logic.en_passant_square, chess_logic.algebraic_to_index("e3"))
	var e7 = chess_logic.algebraic_to_index("e7")
	var e6 = chess_logic.algebraic_to_index("e6")
	chess_logic.make_move(e7, e6)
	assert_eq(chess_logic.en_passant_square, -1, "En passant should be cleared after non-double-push")


func test_make_move_updates_halfmove_clock() -> void:
	chess_logic.parse_fen("8/8/8/8/8/8/4P3/4K2k w - - 10 50")
	var e1 = chess_logic.algebraic_to_index("e1")
	var e2_king = chess_logic.algebraic_to_index("d1")
	chess_logic.make_move(e1, e2_king)
	assert_eq(chess_logic.halfmove_clock, 11, "Halfmove clock should increment for non-pawn, non-capture")


func test_make_move_resets_halfmove_clock_on_pawn() -> void:
	chess_logic.parse_fen("8/8/8/8/8/8/4P3/4K2k w - - 10 50")
	var e2 = chess_logic.algebraic_to_index("e2")
	var e4 = chess_logic.algebraic_to_index("e4")
	chess_logic.make_move(e2, e4)
	assert_eq(chess_logic.halfmove_clock, 0, "Halfmove clock should reset on pawn move")
