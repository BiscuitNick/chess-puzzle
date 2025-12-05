extends GutTest
## Tests for ChessLogic FEN parsing and board state representation.

const ChessLogicScript = preload("res://scripts/autoload/chess_logic.gd")

var chess_logic


func before_each() -> void:
	chess_logic = ChessLogicScript.new()
	add_child(chess_logic)
	chess_logic._ready()


func after_each() -> void:
	chess_logic.queue_free()


func test_starting_position() -> void:
	# Starting position is loaded by default in _ready()
	# Verify piece placement

	# Rank 8 (black pieces)
	assert_eq(chess_logic.board[0], ChessLogicScript.B_ROOK, "a8 should be black rook")
	assert_eq(chess_logic.board[1], ChessLogicScript.B_KNIGHT, "b8 should be black knight")
	assert_eq(chess_logic.board[2], ChessLogicScript.B_BISHOP, "c8 should be black bishop")
	assert_eq(chess_logic.board[3], ChessLogicScript.B_QUEEN, "d8 should be black queen")
	assert_eq(chess_logic.board[4], ChessLogicScript.B_KING, "e8 should be black king")
	assert_eq(chess_logic.board[5], ChessLogicScript.B_BISHOP, "f8 should be black bishop")
	assert_eq(chess_logic.board[6], ChessLogicScript.B_KNIGHT, "g8 should be black knight")
	assert_eq(chess_logic.board[7], ChessLogicScript.B_ROOK, "h8 should be black rook")

	# Rank 7 (black pawns)
	for i in range(8, 16):
		assert_eq(chess_logic.board[i], ChessLogicScript.B_PAWN, "Rank 7 should be black pawns")

	# Ranks 3-6 (empty)
	for i in range(16, 48):
		assert_eq(chess_logic.board[i], ChessLogicScript.EMPTY, "Middle ranks should be empty")

	# Rank 2 (white pawns)
	for i in range(48, 56):
		assert_eq(chess_logic.board[i], ChessLogicScript.W_PAWN, "Rank 2 should be white pawns")

	# Rank 1 (white pieces)
	assert_eq(chess_logic.board[56], ChessLogicScript.W_ROOK, "a1 should be white rook")
	assert_eq(chess_logic.board[57], ChessLogicScript.W_KNIGHT, "b1 should be white knight")
	assert_eq(chess_logic.board[58], ChessLogicScript.W_BISHOP, "c1 should be white bishop")
	assert_eq(chess_logic.board[59], ChessLogicScript.W_QUEEN, "d1 should be white queen")
	assert_eq(chess_logic.board[60], ChessLogicScript.W_KING, "e1 should be white king")
	assert_eq(chess_logic.board[61], ChessLogicScript.W_BISHOP, "f1 should be white bishop")
	assert_eq(chess_logic.board[62], ChessLogicScript.W_KNIGHT, "g1 should be white knight")
	assert_eq(chess_logic.board[63], ChessLogicScript.W_ROOK, "h1 should be white rook")

	# Side to move
	assert_eq(chess_logic.side_to_move, ChessLogicScript.PieceColor.WHITE, "White should move first")

	# Castling rights (all available)
	assert_eq(chess_logic.castling_rights, 15, "All castling rights should be set (K+Q+k+q = 1+2+4+8 = 15)")

	# No en passant
	assert_eq(chess_logic.en_passant_square, -1, "No en passant square")

	# Initial counters
	assert_eq(chess_logic.halfmove_clock, 0, "Halfmove clock should be 0")
	assert_eq(chess_logic.fullmove_number, 1, "Fullmove number should be 1")


func test_castling_rights_partial() -> void:
	# Test with only kingside castling
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w Kk - 0 1")
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_K, ChessLogicScript.CASTLE_K, "White kingside should be set")
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_Q, 0, "White queenside should not be set")
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_k, ChessLogicScript.CASTLE_k, "Black kingside should be set")
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_q, 0, "Black queenside should not be set")

	# Test with only queenside castling
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w Qq - 0 1")
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_K, 0, "White kingside should not be set")
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_Q, ChessLogicScript.CASTLE_Q, "White queenside should be set")
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_k, 0, "Black kingside should not be set")
	assert_eq(chess_logic.castling_rights & ChessLogicScript.CASTLE_q, ChessLogicScript.CASTLE_q, "Black queenside should be set")

	# Test with no castling rights
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w - - 0 1")
	assert_eq(chess_logic.castling_rights, 0, "No castling rights should be set")


func test_en_passant_square() -> void:
	# Test en passant on e3 (after e2-e4)
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
	assert_eq(chess_logic.en_passant_square, chess_logic.algebraic_to_index("e3"), "En passant should be on e3")

	# Test en passant on d6 (after d7-d5)
	chess_logic.parse_fen("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2")
	assert_eq(chess_logic.en_passant_square, chess_logic.algebraic_to_index("d6"), "En passant should be on d6")

	# Test no en passant
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	assert_eq(chess_logic.en_passant_square, -1, "No en passant square")


func test_algebraic_to_index() -> void:
	# Corner squares
	assert_eq(chess_logic.algebraic_to_index("a8"), 0, "a8 should be index 0")
	assert_eq(chess_logic.algebraic_to_index("h8"), 7, "h8 should be index 7")
	assert_eq(chess_logic.algebraic_to_index("a1"), 56, "a1 should be index 56")
	assert_eq(chess_logic.algebraic_to_index("h1"), 63, "h1 should be index 63")

	# Center squares
	assert_eq(chess_logic.algebraic_to_index("e4"), 36, "e4 should be index 36")
	assert_eq(chess_logic.algebraic_to_index("d5"), 27, "d5 should be index 27")

	# Invalid squares
	assert_eq(chess_logic.algebraic_to_index("i1"), -1, "Invalid file should return -1")
	assert_eq(chess_logic.algebraic_to_index("a9"), -1, "Invalid rank should return -1")
	assert_eq(chess_logic.algebraic_to_index(""), -1, "Empty string should return -1")


func test_index_to_algebraic() -> void:
	# Corner squares
	assert_eq(chess_logic.index_to_algebraic(0), "a8", "Index 0 should be a8")
	assert_eq(chess_logic.index_to_algebraic(7), "h8", "Index 7 should be h8")
	assert_eq(chess_logic.index_to_algebraic(56), "a1", "Index 56 should be a1")
	assert_eq(chess_logic.index_to_algebraic(63), "h1", "Index 63 should be h1")

	# Center squares
	assert_eq(chess_logic.index_to_algebraic(36), "e4", "Index 36 should be e4")
	assert_eq(chess_logic.index_to_algebraic(27), "d5", "Index 27 should be d5")

	# Invalid indices
	assert_eq(chess_logic.index_to_algebraic(-1), "", "Invalid index should return empty string")
	assert_eq(chess_logic.index_to_algebraic(64), "", "Invalid index should return empty string")


func test_round_trip_fen() -> void:
	# Test that parse_fen followed by to_fen returns equivalent FEN
	var test_fens = [
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
		"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
		"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
		"8/8/8/8/8/8/8/4K2k w - - 50 100",
	]

	for fen in test_fens:
		chess_logic.parse_fen(fen)
		var result_fen = chess_logic.to_fen()
		assert_eq(result_fen, fen, "Round-trip FEN should match: %s" % fen)


func test_uci_to_squares() -> void:
	# Standard move
	var move = chess_logic.uci_to_squares("e2e4")
	assert_eq(move["from"], chess_logic.algebraic_to_index("e2"), "Source should be e2")
	assert_eq(move["to"], chess_logic.algebraic_to_index("e4"), "Destination should be e4")
	assert_eq(move["promotion"], ChessLogicScript.EMPTY, "No promotion")

	# Promotion to queen (white)
	move = chess_logic.uci_to_squares("e7e8q")
	assert_eq(move["from"], chess_logic.algebraic_to_index("e7"), "Source should be e7")
	assert_eq(move["to"], chess_logic.algebraic_to_index("e8"), "Destination should be e8")
	assert_eq(move["promotion"], ChessLogicScript.W_QUEEN, "Should promote to white queen")

	# Promotion to knight (black)
	move = chess_logic.uci_to_squares("d2d1n")
	assert_eq(move["from"], chess_logic.algebraic_to_index("d2"), "Source should be d2")
	assert_eq(move["to"], chess_logic.algebraic_to_index("d1"), "Destination should be d1")
	assert_eq(move["promotion"], ChessLogicScript.B_KNIGHT, "Should promote to black knight")

	# Castling notation
	move = chess_logic.uci_to_squares("e1g1")  # White kingside castle
	assert_eq(move["from"], chess_logic.algebraic_to_index("e1"), "Source should be e1")
	assert_eq(move["to"], chess_logic.algebraic_to_index("g1"), "Destination should be g1")


func test_squares_to_uci() -> void:
	# Standard move
	var uci = chess_logic.squares_to_uci(
		chess_logic.algebraic_to_index("e2"),
		chess_logic.algebraic_to_index("e4")
	)
	assert_eq(uci, "e2e4", "Should be e2e4")

	# Promotion
	uci = chess_logic.squares_to_uci(
		chess_logic.algebraic_to_index("e7"),
		chess_logic.algebraic_to_index("e8"),
		ChessLogicScript.W_QUEEN
	)
	assert_eq(uci, "e7e8q", "Should be e7e8q")


func test_side_to_move() -> void:
	# White to move
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	assert_eq(chess_logic.side_to_move, ChessLogicScript.PieceColor.WHITE, "White should move")

	# Black to move
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
	assert_eq(chess_logic.side_to_move, ChessLogicScript.PieceColor.BLACK, "Black should move")


func test_halfmove_and_fullmove() -> void:
	chess_logic.parse_fen("8/8/8/8/8/8/8/4K2k w - - 50 100")
	assert_eq(chess_logic.halfmove_clock, 50, "Halfmove clock should be 50")
	assert_eq(chess_logic.fullmove_number, 100, "Fullmove number should be 100")


func test_get_piece() -> void:
	# Starting position
	assert_eq(chess_logic.get_piece(0), ChessLogicScript.B_ROOK, "a8 should be black rook")
	assert_eq(chess_logic.get_piece(60), ChessLogicScript.W_KING, "e1 should be white king")
	assert_eq(chess_logic.get_piece(28), ChessLogicScript.EMPTY, "e5 should be empty")

	# Invalid squares
	assert_eq(chess_logic.get_piece(-1), ChessLogicScript.EMPTY, "Invalid square should return EMPTY")
	assert_eq(chess_logic.get_piece(64), ChessLogicScript.EMPTY, "Invalid square should return EMPTY")


func test_piece_color_helpers() -> void:
	assert_true(chess_logic.is_white_piece(ChessLogicScript.W_PAWN), "W_PAWN should be white")
	assert_true(chess_logic.is_white_piece(ChessLogicScript.W_KING), "W_KING should be white")
	assert_false(chess_logic.is_white_piece(ChessLogicScript.B_PAWN), "B_PAWN should not be white")
	assert_false(chess_logic.is_white_piece(ChessLogicScript.EMPTY), "EMPTY should not be white")

	assert_true(chess_logic.is_black_piece(ChessLogicScript.B_PAWN), "B_PAWN should be black")
	assert_true(chess_logic.is_black_piece(ChessLogicScript.B_KING), "B_KING should be black")
	assert_false(chess_logic.is_black_piece(ChessLogicScript.W_PAWN), "W_PAWN should not be black")
	assert_false(chess_logic.is_black_piece(ChessLogicScript.EMPTY), "EMPTY should not be black")


func test_king_position_tracking() -> void:
	# Starting position
	assert_eq(chess_logic.get_king_square(ChessLogicScript.PieceColor.WHITE), chess_logic.algebraic_to_index("e1"), "White king should be on e1")
	assert_eq(chess_logic.get_king_square(ChessLogicScript.PieceColor.BLACK), chess_logic.algebraic_to_index("e8"), "Black king should be on e8")

	# After parsing a different position
	chess_logic.parse_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
	assert_eq(chess_logic.get_king_square(ChessLogicScript.PieceColor.WHITE), chess_logic.algebraic_to_index("e1"), "White king should still be on e1")
	assert_eq(chess_logic.get_king_square(ChessLogicScript.PieceColor.BLACK), chess_logic.algebraic_to_index("e8"), "Black king should still be on e8")
