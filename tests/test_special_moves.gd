extends GutTest
## Tests for special chess moves: castling, en passant, and pawn promotion.

const ChessLogicScript = preload("res://scripts/autoload/chess_logic.gd")

var chess_logic


func before_each() -> void:
	chess_logic = ChessLogicScript.new()
	add_child(chess_logic)
	chess_logic._ready()


func after_each() -> void:
	chess_logic.queue_free()


# =============================================================================
# KINGSIDE CASTLING TESTS
# =============================================================================

func test_white_kingside_castle() -> void:
	# Position with castling rights, empty squares between king and rook
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")

	assert_true(chess_logic.can_castle_kingside(ChessLogicScript.PieceColor.WHITE), "White should be able to castle kingside")

	var e1 = chess_logic.algebraic_to_index("e1")
	var g1 = chess_logic.algebraic_to_index("g1")

	# King should have g1 in its legal moves
	var king_moves = chess_logic.get_legal_moves(e1)
	assert_true(g1 in king_moves, "g1 should be a legal move for white king (castling)")

	# Execute castling
	assert_true(chess_logic.make_move(e1, g1), "Kingside castling should succeed")

	# Verify king moved to g1
	assert_eq(chess_logic.board[g1], ChessLogicScript.W_KING, "White king should be on g1")
	assert_eq(chess_logic.board[e1], ChessLogicScript.EMPTY, "e1 should be empty")

	# Verify rook moved to f1
	var f1 = chess_logic.algebraic_to_index("f1")
	var h1 = chess_logic.algebraic_to_index("h1")
	assert_eq(chess_logic.board[f1], ChessLogicScript.W_ROOK, "White rook should be on f1")
	assert_eq(chess_logic.board[h1], ChessLogicScript.EMPTY, "h1 should be empty")

	# Verify castling rights cleared
	assert_eq(chess_logic.castling_rights & (ChessLogicScript.CASTLE_K | ChessLogicScript.CASTLE_Q), 0, "White castling rights should be cleared")


func test_black_kingside_castle() -> void:
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R b KQkq - 0 1")

	assert_true(chess_logic.can_castle_kingside(ChessLogicScript.PieceColor.BLACK), "Black should be able to castle kingside")

	var e8 = chess_logic.algebraic_to_index("e8")
	var g8 = chess_logic.algebraic_to_index("g8")

	assert_true(chess_logic.make_move(e8, g8), "Black kingside castling should succeed")

	# Verify positions
	assert_eq(chess_logic.board[g8], ChessLogicScript.B_KING, "Black king should be on g8")
	var f8 = chess_logic.algebraic_to_index("f8")
	assert_eq(chess_logic.board[f8], ChessLogicScript.B_ROOK, "Black rook should be on f8")


# =============================================================================
# QUEENSIDE CASTLING TESTS
# =============================================================================

func test_white_queenside_castle() -> void:
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")

	assert_true(chess_logic.can_castle_queenside(ChessLogicScript.PieceColor.WHITE), "White should be able to castle queenside")

	var e1 = chess_logic.algebraic_to_index("e1")
	var c1 = chess_logic.algebraic_to_index("c1")

	assert_true(chess_logic.make_move(e1, c1), "Queenside castling should succeed")

	# Verify king moved to c1
	assert_eq(chess_logic.board[c1], ChessLogicScript.W_KING, "White king should be on c1")

	# Verify rook moved to d1
	var d1 = chess_logic.algebraic_to_index("d1")
	var a1 = chess_logic.algebraic_to_index("a1")
	assert_eq(chess_logic.board[d1], ChessLogicScript.W_ROOK, "White rook should be on d1")
	assert_eq(chess_logic.board[a1], ChessLogicScript.EMPTY, "a1 should be empty")


func test_black_queenside_castle() -> void:
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R b KQkq - 0 1")

	assert_true(chess_logic.can_castle_queenside(ChessLogicScript.PieceColor.BLACK), "Black should be able to castle queenside")

	var e8 = chess_logic.algebraic_to_index("e8")
	var c8 = chess_logic.algebraic_to_index("c8")

	assert_true(chess_logic.make_move(e8, c8), "Black queenside castling should succeed")

	assert_eq(chess_logic.board[c8], ChessLogicScript.B_KING, "Black king should be on c8")
	var d8 = chess_logic.algebraic_to_index("d8")
	assert_eq(chess_logic.board[d8], ChessLogicScript.B_ROOK, "Black rook should be on d8")


# =============================================================================
# CASTLING ILLEGAL CASES
# =============================================================================

func test_castle_blocked_by_piece() -> void:
	# Knight blocking kingside
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3KN1R w KQkq - 0 1")
	assert_false(chess_logic.can_castle_kingside(ChessLogicScript.PieceColor.WHITE), "Cannot castle with piece in the way")


func test_castle_no_rights() -> void:
	# No castling rights
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w - - 0 1")
	assert_false(chess_logic.can_castle_kingside(ChessLogicScript.PieceColor.WHITE), "Cannot castle without rights")
	assert_false(chess_logic.can_castle_queenside(ChessLogicScript.PieceColor.WHITE), "Cannot castle without rights")


func test_castle_through_check_illegal() -> void:
	# Rook attacks f1 - king would pass through check (no pawn on f2 to block)
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/5r2/PPPPP1PP/R3K2R w KQkq - 0 1")
	assert_false(chess_logic.can_castle_kingside(ChessLogicScript.PieceColor.WHITE), "Cannot castle through check")


func test_castle_into_check_illegal() -> void:
	# Rook attacks g1 - king would land in check (no pawn on g2 to block)
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/6r1/PPPPPP1P/R3K2R w KQkq - 0 1")
	assert_false(chess_logic.can_castle_kingside(ChessLogicScript.PieceColor.WHITE), "Cannot castle into check")


func test_castle_while_in_check_illegal() -> void:
	# Rook attacks e1 - king is in check (no pawn on e2 to block)
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/4r3/PPPP1PPP/R3K2R w KQkq - 0 1")
	assert_false(chess_logic.can_castle_kingside(ChessLogicScript.PieceColor.WHITE), "Cannot castle while in check")
	assert_false(chess_logic.can_castle_queenside(ChessLogicScript.PieceColor.WHITE), "Cannot castle while in check")


func test_castle_rook_missing() -> void:
	# Missing kingside rook
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K3 w KQkq - 0 1")
	assert_false(chess_logic.can_castle_kingside(ChessLogicScript.PieceColor.WHITE), "Cannot castle without rook")


func test_castling_rights_revoked_after_king_move() -> void:
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")

	var e1 = chess_logic.algebraic_to_index("e1")
	var d1 = chess_logic.algebraic_to_index("d1")

	# Move king
	chess_logic.make_move(e1, d1)

	# Verify castling rights cleared for white
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_K, 0, "White K should be cleared")
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_Q, 0, "White Q should be cleared")


func test_castling_rights_revoked_after_rook_move() -> void:
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")

	var h1 = chess_logic.algebraic_to_index("h1")
	var h2 = chess_logic.algebraic_to_index("h2")  # This square has a pawn
	var g1 = chess_logic.algebraic_to_index("g1")

	# Move the h-rook
	chess_logic.make_move(h1, g1)

	# Verify only kingside castling right cleared
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_K, 0, "White K should be cleared")
	assert_ne(chess_logic.castling_rights & ChessLogicScript.CASTLE_Q, 0, "White Q should still be set")


# =============================================================================
# EN PASSANT TESTS
# =============================================================================

func test_en_passant_capture() -> void:
	# White pawn on e5, black pawn just double-pushed to d5
	chess_logic.parse_fen("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 1")

	var e5 = chess_logic.algebraic_to_index("e5")
	var d6 = chess_logic.algebraic_to_index("d6")
	var d5 = chess_logic.algebraic_to_index("d5")

	# Verify en passant square is set
	assert_eq(chess_logic.en_passant_square, d6, "En passant square should be d6")

	# Verify d6 is a legal move for the e5 pawn
	var pawn_moves = chess_logic.get_legal_moves(e5)
	assert_true(d6 in pawn_moves, "En passant capture should be legal")

	# Execute en passant
	assert_true(chess_logic.make_move(e5, d6), "En passant capture should succeed")

	# Verify pawn moved to d6
	assert_eq(chess_logic.board[d6], ChessLogicScript.W_PAWN, "White pawn should be on d6")

	# Verify captured pawn removed from d5
	assert_eq(chess_logic.board[d5], ChessLogicScript.EMPTY, "Black pawn should be captured from d5")


func test_en_passant_black_capture() -> void:
	# Black pawn on d4, white pawn just double-pushed to e4
	chess_logic.parse_fen("rnbqkbnr/pppp1ppp/8/8/3pP3/8/PPP2PPP/RNBQKBNR b KQkq e3 0 1")

	var d4 = chess_logic.algebraic_to_index("d4")
	var e3 = chess_logic.algebraic_to_index("e3")
	var e4 = chess_logic.algebraic_to_index("e4")

	assert_eq(chess_logic.en_passant_square, e3, "En passant square should be e3")

	var pawn_moves = chess_logic.get_legal_moves(d4)
	assert_true(e3 in pawn_moves, "Black en passant capture should be legal")

	assert_true(chess_logic.make_move(d4, e3), "Black en passant capture should succeed")

	assert_eq(chess_logic.board[e3], ChessLogicScript.B_PAWN, "Black pawn should be on e3")
	assert_eq(chess_logic.board[e4], ChessLogicScript.EMPTY, "White pawn should be captured from e4")


func test_double_push_sets_en_passant() -> void:
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

	var e2 = chess_logic.algebraic_to_index("e2")
	var e4 = chess_logic.algebraic_to_index("e4")
	var e3 = chess_logic.algebraic_to_index("e3")

	chess_logic.make_move(e2, e4)

	assert_eq(chess_logic.en_passant_square, e3, "En passant should be set to e3 after e2-e4")


func test_single_push_clears_en_passant() -> void:
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")

	var e7 = chess_logic.algebraic_to_index("e7")
	var e6 = chess_logic.algebraic_to_index("e6")

	chess_logic.make_move(e7, e6)

	assert_eq(chess_logic.en_passant_square, -1, "En passant should be cleared after non-double-push")


func test_en_passant_expires_after_one_move() -> void:
	# Set up with en passant available
	chess_logic.parse_fen("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 1")

	# Make a different move (not en passant)
	var a2 = chess_logic.algebraic_to_index("a2")
	var a3 = chess_logic.algebraic_to_index("a3")
	chess_logic.make_move(a2, a3)

	# En passant should be gone
	assert_eq(chess_logic.en_passant_square, -1, "En passant should expire after not being used")


# =============================================================================
# PAWN PROMOTION TESTS
# =============================================================================

func test_pawn_promotion_default_queen() -> void:
	# White pawn about to promote
	chess_logic.parse_fen("8/P7/8/8/8/8/8/4K2k w - - 0 1")

	var a7 = chess_logic.algebraic_to_index("a7")
	var a8 = chess_logic.algebraic_to_index("a8")

	# Promote without specifying piece (defaults to queen)
	chess_logic.make_move(a7, a8)

	assert_eq(chess_logic.board[a8], ChessLogicScript.W_QUEEN, "Pawn should promote to queen by default")


func test_pawn_promotion_to_knight() -> void:
	chess_logic.parse_fen("8/P7/8/8/8/8/8/4K2k w - - 0 1")

	var a7 = chess_logic.algebraic_to_index("a7")
	var a8 = chess_logic.algebraic_to_index("a8")

	chess_logic.make_move(a7, a8, ChessLogicScript.W_KNIGHT)

	assert_eq(chess_logic.board[a8], ChessLogicScript.W_KNIGHT, "Pawn should promote to knight")


func test_pawn_promotion_to_rook() -> void:
	chess_logic.parse_fen("8/P7/8/8/8/8/8/4K2k w - - 0 1")

	var a7 = chess_logic.algebraic_to_index("a7")
	var a8 = chess_logic.algebraic_to_index("a8")

	chess_logic.make_move(a7, a8, ChessLogicScript.W_ROOK)

	assert_eq(chess_logic.board[a8], ChessLogicScript.W_ROOK, "Pawn should promote to rook")


func test_pawn_promotion_to_bishop() -> void:
	chess_logic.parse_fen("8/P7/8/8/8/8/8/4K2k w - - 0 1")

	var a7 = chess_logic.algebraic_to_index("a7")
	var a8 = chess_logic.algebraic_to_index("a8")

	chess_logic.make_move(a7, a8, ChessLogicScript.W_BISHOP)

	assert_eq(chess_logic.board[a8], ChessLogicScript.W_BISHOP, "Pawn should promote to bishop")


func test_black_pawn_promotion() -> void:
	chess_logic.parse_fen("4k3/8/8/8/8/8/p7/4K3 b - - 0 1")

	var a2 = chess_logic.algebraic_to_index("a2")
	var a1 = chess_logic.algebraic_to_index("a1")

	chess_logic.make_move(a2, a1, ChessLogicScript.B_QUEEN)

	assert_eq(chess_logic.board[a1], ChessLogicScript.B_QUEEN, "Black pawn should promote to queen")


func test_promotion_with_capture() -> void:
	# White pawn can capture and promote
	chess_logic.parse_fen("rn2k3/P7/8/8/8/8/8/4K3 w - - 0 1")

	var a7 = chess_logic.algebraic_to_index("a7")
	var b8 = chess_logic.algebraic_to_index("b8")

	var pawn_moves = chess_logic.get_legal_moves(a7)
	assert_true(b8 in pawn_moves, "Pawn should be able to capture and promote on b8")

	chess_logic.make_move(a7, b8, ChessLogicScript.W_QUEEN)

	assert_eq(chess_logic.board[b8], ChessLogicScript.W_QUEEN, "Pawn should capture and promote to queen")


# =============================================================================
# GAME STATE UPDATES
# =============================================================================

func test_halfmove_clock_reset_on_pawn_move() -> void:
	chess_logic.parse_fen("4k3/8/8/8/8/8/4P3/4K3 w - - 10 50")

	var e2 = chess_logic.algebraic_to_index("e2")
	var e4 = chess_logic.algebraic_to_index("e4")

	chess_logic.make_move(e2, e4)

	assert_eq(chess_logic.halfmove_clock, 0, "Halfmove clock should reset on pawn move")


func test_halfmove_clock_reset_on_capture() -> void:
	chess_logic.parse_fen("4k3/8/8/8/8/3p4/4P3/4K3 w - - 10 50")

	var e2 = chess_logic.algebraic_to_index("e2")
	var d3 = chess_logic.algebraic_to_index("d3")

	chess_logic.make_move(e2, d3)

	assert_eq(chess_logic.halfmove_clock, 0, "Halfmove clock should reset on capture")


func test_halfmove_clock_increment() -> void:
	chess_logic.parse_fen("4k3/8/8/8/8/8/8/R3K3 w - - 10 50")

	var a1 = chess_logic.algebraic_to_index("a1")
	var b1 = chess_logic.algebraic_to_index("b1")

	chess_logic.make_move(a1, b1)

	assert_eq(chess_logic.halfmove_clock, 11, "Halfmove clock should increment on non-pawn, non-capture move")


func test_fullmove_increment_after_black() -> void:
	chess_logic.parse_fen("4k3/8/8/8/8/8/8/4K3 b - - 0 50")

	var e8 = chess_logic.algebraic_to_index("e8")
	var d8 = chess_logic.algebraic_to_index("d8")

	chess_logic.make_move(e8, d8)

	assert_eq(chess_logic.fullmove_number, 51, "Fullmove number should increment after black moves")


func test_fullmove_no_increment_after_white() -> void:
	chess_logic.parse_fen("4k3/8/8/8/8/8/8/4K3 w - - 0 50")

	var e1 = chess_logic.algebraic_to_index("e1")
	var d1 = chess_logic.algebraic_to_index("d1")

	chess_logic.make_move(e1, d1)

	assert_eq(chess_logic.fullmove_number, 50, "Fullmove number should not increment after white moves")
