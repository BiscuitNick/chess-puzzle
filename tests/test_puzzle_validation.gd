extends GutTest
## Tests for puzzle validation logic.
## Tests the PuzzleValidator class for correct/incorrect move detection.

const ChessLogicScript = preload("res://scripts/autoload/chess_logic.gd")
const PuzzleValidatorScript = preload("res://scripts/puzzle/puzzle_validator.gd")

var chess_logic


func before_each() -> void:
	chess_logic = ChessLogicScript.new()
	add_child(chess_logic)
	chess_logic._ready()


func after_each() -> void:
	chess_logic.queue_free()


# =============================================================================
# CORRECT MOVE DETECTION (using ChessLogic directly for unit tests)
# =============================================================================

func test_checkmate_move_detected() -> void:
	# Mate in 1 position: Qh7#
	chess_logic.parse_fen("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")

	var h5 = chess_logic.algebraic_to_index("h5")
	var f7 = chess_logic.algebraic_to_index("f7")

	# Make the move
	chess_logic.make_move(h5, f7)

	# Verify checkmate
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Qxf7 should be checkmate")


func test_non_checkmate_move_not_checkmate() -> void:
	# Same position but make a different move
	chess_logic.parse_fen("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")

	var h5 = chess_logic.algebraic_to_index("h5")
	var e5 = chess_logic.algebraic_to_index("e5")

	# Make a different move (Qxe5)
	chess_logic.make_move(h5, e5)

	# Verify NOT checkmate
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Qxe5 should not be checkmate")


func test_back_rank_mate_move() -> void:
	# Position where Rc8# is checkmate
	chess_logic.parse_fen("6k1/5ppp/8/8/8/8/5PPP/R3R1K1 w - - 0 1")

	var a1 = chess_logic.algebraic_to_index("a1")
	var a8 = chess_logic.algebraic_to_index("a8")

	chess_logic.make_move(a1, a8)

	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Ra8 should be checkmate")


# =============================================================================
# ALTERNATE MATE DETECTION
# =============================================================================

func test_multiple_mates_position() -> void:
	# Position with multiple checkmate options
	chess_logic.parse_fen("6k1/5ppp/8/8/8/4Q3/5PPP/4R1K1 w - - 0 1")

	# Check that Qe8 is checkmate
	var e3 = chess_logic.algebraic_to_index("e3")
	var e8 = chess_logic.algebraic_to_index("e8")

	var temp_logic = ChessLogicScript.new()
	add_child(temp_logic)
	temp_logic._ready()
	temp_logic.parse_fen("6k1/5ppp/8/8/8/4Q3/5PPP/4R1K1 w - - 0 1")
	temp_logic.make_move(e3, e8)

	assert_true(temp_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Qe8 should be checkmate")
	temp_logic.queue_free()


# =============================================================================
# ILLEGAL MOVE REJECTION
# =============================================================================

func test_illegal_move_rejected() -> void:
	chess_logic.parse_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

	var e2 = chess_logic.algebraic_to_index("e2")
	var e5 = chess_logic.algebraic_to_index("e5")  # Invalid - pawn can't move 3 squares

	# Pawn can only move to e3 or e4, not e5
	assert_false(chess_logic.is_move_legal(e2, e5), "Pawn moving 3 squares should be illegal")


func test_move_into_check_rejected() -> void:
	# King can't move to attacked square
	chess_logic.parse_fen("8/8/8/4r3/8/8/8/4K3 w - - 0 1")

	var e1 = chess_logic.algebraic_to_index("e1")
	var e2 = chess_logic.algebraic_to_index("e2")  # This square is attacked by rook

	assert_false(chess_logic.is_move_legal(e1, e2), "King can't move into check")


func test_pinned_piece_cant_move_off_pin() -> void:
	# Bishop is pinned to king by rook (orthogonally)
	# Since bishops move diagonally and the pin is orthogonal, bishop has NO legal moves
	chess_logic.parse_fen("4r3/8/8/8/8/4B3/8/4K3 w - - 0 1")

	var e3 = chess_logic.algebraic_to_index("e3")

	# Get legal moves for the bishop
	var legal_moves = chess_logic.get_legal_moves(e3)

	# Bishop pinned orthogonally has no legal moves (can only move diagonally, off the pin)
	assert_eq(legal_moves.size(), 0, "Orthogonally pinned bishop has no legal moves")


# =============================================================================
# SLOWER MATE REJECTION LOGIC (unit test)
# =============================================================================

func test_accepts_alternate_mate_logic() -> void:
	var validator = PuzzleValidatorScript.new()

	# Faster mate is acceptable
	assert_true(validator.accepts_alternate_mate(3, 2), "Faster mate (2 vs expected 3) should be accepted")
	assert_true(validator.accepts_alternate_mate(3, 1), "Faster mate (1 vs expected 3) should be accepted")

	# Same length mate is acceptable
	assert_true(validator.accepts_alternate_mate(2, 2), "Same length mate should be accepted")

	# Slower mate is NOT acceptable
	assert_false(validator.accepts_alternate_mate(2, 3), "Slower mate (3 vs expected 2) should be rejected")
	assert_false(validator.accepts_alternate_mate(1, 2), "Slower mate (2 vs expected 1) should be rejected")

	# Zero or negative mate values should be rejected
	assert_false(validator.accepts_alternate_mate(2, 0), "Zero mate distance should be rejected")
	assert_false(validator.accepts_alternate_mate(2, -1), "Negative mate should be rejected")


# =============================================================================
# CHECKMATE POSITION VERIFICATION
# =============================================================================

func test_validator_is_checkmate() -> void:
	var validator = PuzzleValidatorScript.new()

	# Clear checkmate position
	var mate_fen = "R5k1/5ppp/8/8/8/8/8/4K3 b - - 0 1"
	assert_true(validator.is_checkmate(mate_fen), "Back rank mate position should be checkmate")

	# Not checkmate - king can escape
	var escape_fen = "R5k1/6pp/8/8/8/8/8/4K3 b - - 0 1"
	assert_false(validator.is_checkmate(escape_fen), "King can escape to f7")


func test_smothered_mate_position() -> void:
	var validator = PuzzleValidatorScript.new()

	# Classic smothered mate
	var fen = "6rk/5Npp/8/8/8/8/8/4K3 b - - 0 1"
	assert_true(validator.is_checkmate(fen), "Smothered mate should be detected")


func test_stalemate_not_checkmate() -> void:
	var validator = PuzzleValidatorScript.new()

	# Stalemate position
	var fen = "k7/2Q5/8/8/8/8/8/4K3 b - - 0 1"
	assert_false(validator.is_checkmate(fen), "Stalemate should not be checkmate")

	# Verify it's actually stalemate
	chess_logic.parse_fen(fen)
	assert_true(chess_logic.is_stalemate(ChessLogicScript.PieceColor.BLACK), "Position should be stalemate")


# =============================================================================
# MOVE VALIDATION (without engine - testing the logic)
# =============================================================================

func test_uci_move_parsing() -> void:
	# Test UCI move parsing
	var move = chess_logic.uci_to_squares("e2e4")
	assert_eq(move["from"], chess_logic.algebraic_to_index("e2"))
	assert_eq(move["to"], chess_logic.algebraic_to_index("e4"))
	assert_eq(move["promotion"], ChessLogicScript.EMPTY)


func test_uci_promotion_parsing() -> void:
	# Test promotion parsing
	var move = chess_logic.uci_to_squares("e7e8q")
	assert_eq(move["from"], chess_logic.algebraic_to_index("e7"))
	assert_eq(move["to"], chess_logic.algebraic_to_index("e8"))
	assert_eq(move["promotion"], ChessLogicScript.W_QUEEN)


func test_invalid_uci_handling() -> void:
	# Test invalid UCI format
	var move = chess_logic.uci_to_squares("invalid")
	assert_eq(move["from"], -1, "Invalid UCI should return -1 for from")


# =============================================================================
# PUZZLE MOVE SEQUENCE VALIDATION
# =============================================================================

func test_puzzle_solution_sequence() -> void:
	# Simulate a mate-in-2 puzzle sequence
	# Position: After 1. Qf7+ Kh8 2. Qf8#
	chess_logic.parse_fen("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")

	# Move 1: Qf7+
	var h5 = chess_logic.algebraic_to_index("h5")
	var f7 = chess_logic.algebraic_to_index("f7")

	assert_true(chess_logic.is_move_legal(h5, f7), "Qf7 should be legal")
	chess_logic.make_move(h5, f7)

	# This is actually checkmate, not check
	assert_true(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Scholar's mate is checkmate")


func test_puzzle_wrong_move_allows_escape() -> void:
	# If we make a wrong move, the opponent can escape
	chess_logic.parse_fen("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")

	# Wrong move: Qxe5 instead of Qf7
	var h5 = chess_logic.algebraic_to_index("h5")
	var e5 = chess_logic.algebraic_to_index("e5")

	chess_logic.make_move(h5, e5)

	# Not checkmate - black can continue
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK), "Qxe5 is not checkmate")
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Qxe5 gives check")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_empty_position_handling() -> void:
	# Test with minimal position
	chess_logic.parse_fen("8/8/8/8/8/8/8/4K2k w - - 0 1")

	# No checkmate possible
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.WHITE))
	assert_false(chess_logic.is_checkmate(ChessLogicScript.PieceColor.BLACK))


func test_promotion_to_checkmate() -> void:
	# Pawn promotion that gives checkmate
	chess_logic.parse_fen("7k/P7/8/8/8/8/8/4K3 w - - 0 1")

	var a7 = chess_logic.algebraic_to_index("a7")
	var a8 = chess_logic.algebraic_to_index("a8")

	# Promote to queen
	chess_logic.make_move(a7, a8, ChessLogicScript.W_QUEEN)

	# This should give check (not quite checkmate in this position)
	assert_true(chess_logic.is_in_check(ChessLogicScript.PieceColor.BLACK), "Promotion should give check")
