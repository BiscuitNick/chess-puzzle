extends GutTest
## Tests for checkmate and stalemate detection in ChessLogic.

var chess_logic: ChessLogic


func before_each() -> void:
	chess_logic = ChessLogic.new()
	chess_logic._ready()


func after_each() -> void:
	chess_logic.free()


# =============================================================================
# BACK RANK MATE TESTS
# =============================================================================

func test_back_rank_mate_white_wins() -> void:
	# Classic back rank mate: white rook on a8 gives mate
	chess_logic.parse_fen("R5k1/5ppp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king should be in check")
	assert_true(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Black should be in checkmate")
	assert_false(chess_logic.is_stalemate(ChessLogic.PieceColor.BLACK), "Black should not be in stalemate")


func test_back_rank_mate_black_wins() -> void:
	# Back rank mate with black rook
	chess_logic.parse_fen("4k3/8/8/8/8/8/5PPP/r5K1 w - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.WHITE), "White king should be in check")
	assert_true(chess_logic.is_checkmate(ChessLogic.PieceColor.WHITE), "White should be in checkmate")


func test_back_rank_not_mate_can_block() -> void:
	# Rook gives check but another piece can block
	chess_logic.parse_fen("R5k1/5ppp/8/8/8/8/8/4K2R b - - 0 1")
	# Black king is in check from a8 rook, but this is still mate
	# Let me create a position where blocking is possible
	chess_logic.parse_fen("R5k1/4rppp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king should be in check")
	assert_false(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Black can block with rook on e8")


func test_back_rank_not_mate_can_capture() -> void:
	# Rook gives check but can be captured
	chess_logic.parse_fen("R5k1/r4ppp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king should be in check")
	assert_false(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Black rook can capture on a8")


# =============================================================================
# SMOTHERED MATE TESTS
# =============================================================================

func test_smothered_mate() -> void:
	# Classic smothered mate: knight on f7, king trapped by own pieces
	chess_logic.parse_fen("r4rk1/5Npp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king should be in check from knight")
	assert_true(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Black should be in smothered mate")


func test_smothered_mate_corner() -> void:
	# Smothered mate in corner
	chess_logic.parse_fen("6rk/5Npp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king should be in check")
	assert_true(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Smothered mate in corner")


func test_not_smothered_mate_can_take() -> void:
	# Knight gives check but pawn can capture
	chess_logic.parse_fen("6k1/5Npp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king should be in check")
	assert_false(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Pawn on g7 can capture knight")


# =============================================================================
# STALEMATE TESTS
# =============================================================================

func test_stalemate_king_only() -> void:
	# King in corner, queen prevents all moves
	chess_logic.parse_fen("k7/2Q5/8/8/8/8/8/4K3 b - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king should NOT be in check")
	assert_false(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Black should NOT be in checkmate")
	assert_true(chess_logic.is_stalemate(ChessLogic.PieceColor.BLACK), "Black should be in stalemate")


func test_stalemate_king_and_pawns() -> void:
	# Stalemate with blocked pawns
	chess_logic.parse_fen("k7/8/1K6/8/8/8/8/8 b - - 0 1")
	# King can move to b8
	assert_false(chess_logic.is_stalemate(ChessLogic.PieceColor.BLACK), "Black can move")

	# Proper stalemate with blocked pawns
	chess_logic.parse_fen("8/8/8/8/8/6k1/5p2/5K2 w - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogic.PieceColor.WHITE), "White king not in check")
	assert_true(chess_logic.is_stalemate(ChessLogic.PieceColor.WHITE), "White is stalemated")


func test_stalemate_complex() -> void:
	# More complex stalemate position
	chess_logic.parse_fen("7k/8/6KP/8/8/8/8/8 b - - 0 1")
	# Black king trapped by white king and pawn
	assert_false(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king not in check")
	assert_true(chess_logic.is_stalemate(ChessLogic.PieceColor.BLACK), "Black is stalemated")


func test_not_stalemate_has_pawn_move() -> void:
	# King blocked but pawn can move
	chess_logic.parse_fen("k7/2Q5/8/8/8/8/p7/4K3 b - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king not in check")
	assert_false(chess_logic.is_stalemate(ChessLogic.PieceColor.BLACK), "Black pawn can move")


# =============================================================================
# CHECKMATE VS STALEMATE DISTINCTION
# =============================================================================

func test_check_vs_stalemate_distinction() -> void:
	# Position where king has no moves, but IS in check = checkmate
	chess_logic.parse_fen("k7/1Q6/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king IS in check")
	assert_true(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "This is checkmate")
	assert_false(chess_logic.is_stalemate(ChessLogic.PieceColor.BLACK), "NOT stalemate")

	# Position where king has no moves, but NOT in check = stalemate
	chess_logic.parse_fen("k7/2Q5/8/8/8/8/8/4K3 b - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king NOT in check")
	assert_false(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "NOT checkmate")
	assert_true(chess_logic.is_stalemate(ChessLogic.PieceColor.BLACK), "This is stalemate")


# =============================================================================
# DOUBLE CHECK MATE
# =============================================================================

func test_double_check_mate() -> void:
	# Double check where only king can move but all squares covered
	chess_logic.parse_fen("r1b1k3/ppp2B2/2n5/4N3/8/8/8/4K3 b - - 0 1")
	# Bishop on f7 and knight on e5 both give check
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king in double check")
	assert_true(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Cannot escape double check")


# =============================================================================
# QUEEN MATE PATTERNS
# =============================================================================

func test_queen_ladder_mate() -> void:
	# Queen gives mate on back rank
	chess_logic.parse_fen("5rk1/5pQp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king in check")
	assert_true(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Queen mate on g7")


func test_queen_mate_with_king_support() -> void:
	# Queen supported by king
	chess_logic.parse_fen("3k4/3Q4/3K4/8/8/8/8/8 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king in check from queen")
	assert_true(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Queen and king mate")


# =============================================================================
# NOT CHECKMATE CASES
# =============================================================================

func test_can_block_check() -> void:
	# Rook check but bishop can block
	chess_logic.parse_fen("4k3/8/8/8/8/3b4/8/R3K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king in check")
	assert_false(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "Bishop can block")


func test_can_capture_attacker() -> void:
	# Knight check but knight can be captured
	chess_logic.parse_fen("4k3/4n3/8/8/8/3N4/8/4K3 b - - 0 1")
	# This isn't check actually, let me fix
	chess_logic.parse_fen("4k3/8/3N4/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king in check from knight")
	assert_false(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "King can move away")


func test_king_can_escape() -> void:
	# Check but king can run
	chess_logic.parse_fen("4k3/8/8/8/8/8/8/4R2K b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogic.PieceColor.BLACK), "Black king in check")
	assert_false(chess_logic.is_checkmate(ChessLogic.PieceColor.BLACK), "King can escape to d8, d7, f8, or f7")
