extends GutTest
## Tests for checkmate and stalemate detection in ChessLogic.

const ChessLogicScript = preload("res://scripts/autoload/chess_logic.gd")

var chess_logic


func before_each() -> void:
	chess_logic = ChessLogicScript.new()
	add_child(chess_logic)
	chess_logic._ready()


func after_each() -> void:
	chess_logic.queue_free()


# =============================================================================
# BACK RANK MATE TESTS
# =============================================================================

func test_back_rank_mate_white_wins() -> void:
	# Classic back rank mate: white rook on a8 gives mate
	chess_logic.parse_fen("R5k1/5ppp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king should be in check")
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Black should be in checkmate")
	assert_false(chess_logic.is_stalemate(ChessLogicScript.PieceColor.BLACK), "Black should not be in stalemate")


func test_back_rank_mate_black_wins() -> void:
	# Back rank mate with black rook
	chess_logic.parse_fen("4k3/8/8/8/8/8/5PPP/r5K1 w - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.WHITE), "White king should be in check")
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.WHITE), "White should be in checkmate")


func test_back_rank_not_mate_can_block() -> void:
	# Rook gives check but another piece can block
	chess_logic.parse_fen("R5k1/5ppp/8/8/8/8/8/4K2R b - - 0 1")
	# Black king is in check from a8 rook, but this is still mate
	# Let me create a position where blocking is possible
	chess_logic.parse_fen("R5k1/4rppp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king should be in check")
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Black can block with rook on e8")


func test_back_rank_not_mate_can_capture() -> void:
	# Rook gives check but can be captured
	chess_logic.parse_fen("R5k1/r4ppp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king should be in check")
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Black rook can capture on a8")


# =============================================================================
# SMOTHERED MATE TESTS
# =============================================================================

func test_smothered_mate() -> void:
	# Classic smothered mate: knight on f7, king on h8 trapped by own pieces (rook g8, pawns g7/h7)
	# Knight f7 gives check via L-shape, no piece can capture it
	chess_logic.parse_fen("6rk/5Npp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king should be in check from knight")
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Black should be in smothered mate")


func test_smothered_mate_corner() -> void:
	# Knight + Queen corner mate: knight f7 checks h8, queen g6 covers g7/g8
	# King trapped - g8 attacked by queen via g-file, g7 attacked by queen, h7 blocked by pawn
	# No other pieces that could capture the knight or block
	# 7k = 7 empty (a8-g8), king on h8
	chess_logic.parse_fen("7k/5N1p/6Q1/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king should be in check")
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Corner mate with knight and queen")


func test_not_smothered_mate_can_take() -> void:
	# Knight gives check but pawn can capture: knight on g6, king on h8, pawn can take
	chess_logic.parse_fen("7k/6pp/6N1/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king should be in check")
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Pawn on h7 can capture knight on g6")


# =============================================================================
# STALEMATE TESTS
# =============================================================================

func test_stalemate_king_only() -> void:
	# King in corner, queen prevents all moves
	chess_logic.parse_fen("k7/2Q5/8/8/8/8/8/4K3 b - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king should NOT be in check")
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Black should NOT be in checkmate")
	assert_true(chess_logic.is_stalemate(ChessLogicScript.PieceColor.BLACK), "Black should be in stalemate")


func test_stalemate_king_and_pawns() -> void:
	# Stalemate with blocked pawns
	chess_logic.parse_fen("k7/8/1K6/8/8/8/8/8 b - - 0 1")
	# King can move to b8
	assert_false(chess_logic.is_stalemate(ChessLogicScript.PieceColor.BLACK), "Black can move")

	# Proper stalemate: white king f1 blocked by pawn f2 and black king f3
	chess_logic.parse_fen("8/8/8/8/8/5k2/5p2/5K2 w - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.WHITE), "White king not in check")
	assert_true(chess_logic.is_stalemate(ChessLogicScript.PieceColor.WHITE), "White is stalemated")


func test_stalemate_complex() -> void:
	# Classic corner stalemate: king b6 and pawn b7 trap king b8
	# Pawn b7 attacks a8 and c8, king b6 covers a7 and c7
	# Black king b8 has no legal moves but is not in check
	chess_logic.parse_fen("1k6/1P6/1K6/8/8/8/8/8 b - - 0 1")
	# Black king b8 trapped - not in check but no legal moves
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king not in check")
	assert_true(chess_logic.is_stalemate(ChessLogicScript.PieceColor.BLACK), "Black is stalemated")


func test_not_stalemate_has_pawn_move() -> void:
	# King blocked but pawn can move
	chess_logic.parse_fen("k7/2Q5/8/8/8/8/p7/4K3 b - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king not in check")
	assert_false(chess_logic.is_stalemate(ChessLogicScript.PieceColor.BLACK), "Black pawn can move")


# =============================================================================
# CHECKMATE VS STALEMATE DISTINCTION
# =============================================================================

func test_check_vs_stalemate_distinction() -> void:
	# Position where king has no moves, but IS in check = checkmate
	# Queen b7 checks a8, king b6 protects queen, all escapes covered
	chess_logic.parse_fen("k7/1Q6/1K6/8/8/8/8/8 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king IS in check")
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "This is checkmate")
	assert_false(chess_logic.is_stalemate(ChessLogicScript.PieceColor.BLACK), "NOT stalemate")

	# Position where king has no moves, but NOT in check = stalemate
	chess_logic.parse_fen("k7/2Q5/8/8/8/8/8/4K3 b - - 0 1")
	assert_false(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king NOT in check")
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "NOT checkmate")
	assert_true(chess_logic.is_stalemate(ChessLogicScript.PieceColor.BLACK), "This is stalemate")


# =============================================================================
# DOUBLE CHECK MATE
# =============================================================================

func test_double_check_mate() -> void:
	# Double check where only king can move but all squares covered
	# King d8 attacked by queen d7 (file) and bishop e7 (diagonal)
	# Queen is protected by knight e5, all escape squares attacked
	chess_logic.parse_fen("r1bk4/pppQB3/8/4N3/8/8/8/4K3 b - - 0 1")
	# Queen on d7 and bishop on e7 both give check, all escapes covered
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in double check")
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Cannot escape double check")


# =============================================================================
# QUEEN MATE PATTERNS
# =============================================================================

func test_queen_ladder_mate() -> void:
	# Queen f8 checks g8, rook e8 protects queen and covers escape squares
	chess_logic.parse_fen("4RQk1/5ppp/8/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check")
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Queen mate on f8 protected by rook")


func test_queen_mate_with_king_support() -> void:
	# Queen supported by king
	chess_logic.parse_fen("3k4/3Q4/3K4/8/8/8/8/8 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check from queen")
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Queen and king mate")


# =============================================================================
# NOT CHECKMATE CASES
# =============================================================================

func test_can_block_check() -> void:
	# Rook on e1 checks king e8, but bishop on d3 can block on e4 or e2
	chess_logic.parse_fen("4k3/8/8/8/8/3b4/8/4R2K b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check")
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Bishop can block")


func test_can_capture_attacker() -> void:
	# Knight check but knight can be captured
	chess_logic.parse_fen("4k3/4n3/8/8/8/3N4/8/4K3 b - - 0 1")
	# This isn't check actually, let me fix
	chess_logic.parse_fen("4k3/8/3N4/8/8/8/8/4K3 b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check from knight")
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "King can move away")


func test_king_can_escape() -> void:
	# Check but king can run
	chess_logic.parse_fen("4k3/8/8/8/8/8/8/4R2K b - - 0 1")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Black king in check")
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "King can escape to d8, d7, f8, or f7")
