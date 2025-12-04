class_name ChessBoard
extends Node2D
## Visual chess board with piece rendering, highlighting, and coordinate conversion.

## Emitted when a square is clicked
signal square_clicked(square: int)

## Emitted when a piece is selected
signal piece_selected(square: int)

## Emitted when a move is attempted
signal move_attempted(from: int, to: int)

# Board appearance
@export var square_size: int = 80
@export var light_color: Color = Color("#F0D9B5")
@export var dark_color: Color = Color("#B58863")
@export var highlight_color: Color = Color("#829769", 0.8)
@export var last_move_color: Color = Color("#CDD26A", 0.5)
@export var selected_color: Color = Color("#646D40", 0.7)
@export var legal_move_color: Color = Color("#646D40", 0.6)

# Board state
var flipped: bool = false
var selected_square: int = -1
var legal_move_squares: Array[int] = []
var last_move_from: int = -1
var last_move_to: int = -1

# Piece sprites container
var _pieces_container: Node2D
var _piece_sprites: Dictionary = {}  # square index -> Sprite2D

# Piece textures
var _piece_textures: Dictionary = {}

# Constants for piece FEN mapping
const PIECE_FILES = {
	'K': "white_king", 'Q': "white_queen", 'R': "white_rook",
	'B': "white_bishop", 'N': "white_knight", 'P': "white_pawn",
	'k': "black_king", 'q': "black_queen", 'r': "black_rook",
	'b': "black_bishop", 'n': "black_knight", 'p': "black_pawn"
}


func _ready() -> void:
	_pieces_container = Node2D.new()
	_pieces_container.name = "Pieces"
	add_child(_pieces_container)

	_load_piece_textures()


func _load_piece_textures() -> void:
	for fen_char in PIECE_FILES:
		var file_name = PIECE_FILES[fen_char]
		var path = "res://assets/pieces/%s.svg" % file_name
		var texture = load(path)
		if texture:
			_piece_textures[fen_char] = texture
		else:
			push_warning("Failed to load piece texture: %s" % path)


func _draw() -> void:
	# Draw the 8x8 grid
	for rank in range(8):
		for file in range(8):
			var is_light = (rank + file) % 2 == 0
			var color = light_color if is_light else dark_color
			var rect = Rect2(file * square_size, rank * square_size, square_size, square_size)
			draw_rect(rect, color)

	# Draw last move highlight
	if last_move_from >= 0:
		_draw_square_highlight(last_move_from, last_move_color)
	if last_move_to >= 0:
		_draw_square_highlight(last_move_to, last_move_color)

	# Draw selected square highlight
	if selected_square >= 0:
		_draw_square_highlight(selected_square, selected_color)

	# Draw legal move indicators
	for square in legal_move_squares:
		_draw_legal_move_indicator(square)


func _draw_square_highlight(square: int, color: Color) -> void:
	var screen_pos = board_to_screen(square)
	var rect = Rect2(
		screen_pos.x - square_size / 2.0,
		screen_pos.y - square_size / 2.0,
		square_size,
		square_size
	)
	draw_rect(rect, color)


func _draw_legal_move_indicator(square: int) -> void:
	var screen_pos = board_to_screen(square)
	var has_piece = _piece_sprites.has(square)

	if has_piece:
		# Draw a ring around capture squares
		draw_arc(screen_pos, square_size * 0.4, 0, TAU, 32, legal_move_color, 4.0)
	else:
		# Draw a dot on empty squares
		draw_circle(screen_pos, square_size * 0.15, legal_move_color)


## Set the board position from a FEN string.
func set_position(fen: String) -> void:
	# Clear existing pieces
	for child in _pieces_container.get_children():
		child.queue_free()
	_piece_sprites.clear()

	# Parse FEN - only the piece placement part
	var fen_parts = fen.split(" ")
	if fen_parts.is_empty():
		return

	var piece_placement = fen_parts[0]
	var ranks = piece_placement.split("/")

	if ranks.size() != 8:
		push_error("Invalid FEN: expected 8 ranks, got %d" % ranks.size())
		return

	var square = 0
	for rank_str in ranks:
		for c in rank_str:
			if c.is_valid_int():
				# Skip empty squares
				square += int(c)
			elif PIECE_FILES.has(c):
				# Place piece
				_add_piece(c, square)
				square += 1
			else:
				push_error("Invalid FEN character: %s" % c)
				return


func _add_piece(fen_char: String, square: int) -> void:
	if not _piece_textures.has(fen_char):
		push_warning("No texture for piece: %s" % fen_char)
		return

	var sprite = Sprite2D.new()
	sprite.texture = _piece_textures[fen_char]

	# Scale sprite to fit square (with some padding)
	var tex_size = sprite.texture.get_size()
	var target_size = square_size * 0.9
	var scale_factor = target_size / max(tex_size.x, tex_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)

	sprite.position = board_to_screen(square)
	_pieces_container.add_child(sprite)
	_piece_sprites[square] = sprite


## Convert board square index (0-63) to screen position.
## Square 0 = a8, Square 63 = h1 in standard orientation.
func board_to_screen(square: int) -> Vector2:
	var file = square % 8
	var rank = square / 8

	if flipped:
		file = 7 - file
		rank = 7 - rank

	return Vector2(
		file * square_size + square_size / 2.0,
		rank * square_size + square_size / 2.0
	)


## Convert screen position to board square index.
## Returns -1 if outside the board.
func screen_to_board(screen_pos: Vector2) -> int:
	var file = int(screen_pos.x / square_size)
	var rank = int(screen_pos.y / square_size)

	if file < 0 or file > 7 or rank < 0 or rank > 7:
		return -1

	if flipped:
		file = 7 - file
		rank = 7 - rank

	return rank * 8 + file


## Flip the board orientation.
func flip_board() -> void:
	flipped = not flipped
	_update_piece_positions()
	queue_redraw()


func _update_piece_positions() -> void:
	for square in _piece_sprites:
		var sprite = _piece_sprites[square]
		sprite.position = board_to_screen(square)


## Set the last move highlight.
func set_last_move(from: int, to: int) -> void:
	last_move_from = from
	last_move_to = to
	queue_redraw()


## Clear all highlights.
func clear_highlights() -> void:
	selected_square = -1
	legal_move_squares.clear()
	queue_redraw()


## Set selected square and legal moves.
func set_selection(square: int, legal_moves: Array[int]) -> void:
	selected_square = square
	legal_move_squares = legal_moves
	queue_redraw()


## Clear selection.
func clear_selection() -> void:
	selected_square = -1
	legal_move_squares.clear()
	queue_redraw()


## Handle input for square clicking.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = get_local_mouse_position()
			var square = screen_to_board(local_pos)

			if square >= 0:
				square_clicked.emit(square)

				# If we have a selection and clicked a legal move, attempt the move
				if selected_square >= 0 and square in legal_move_squares:
					move_attempted.emit(selected_square, square)
				# If clicked on a piece, select it
				elif _piece_sprites.has(square):
					piece_selected.emit(square)
				else:
					clear_selection()


## Get the total board size.
func get_board_size() -> Vector2:
	return Vector2(square_size * 8, square_size * 8)


## Move a piece visually (for animation or immediate move).
func move_piece(from: int, to: int) -> void:
	if not _piece_sprites.has(from):
		return

	# Remove any piece at destination
	if _piece_sprites.has(to):
		_piece_sprites[to].queue_free()

	# Move the piece
	var sprite = _piece_sprites[from]
	sprite.position = board_to_screen(to)

	# Update tracking
	_piece_sprites.erase(from)
	_piece_sprites[to] = sprite

	# Update last move highlight
	set_last_move(from, to)
