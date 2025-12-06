class_name ChessBoard
extends Control
## Visual chess board with piece rendering, highlighting, and coordinate conversion.

const BUILD_NUMBER = 7  # Increment this after each code change for debugging

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
@export var hint_color: Color = Color("#4A90D9", 0.8)

# Board state
var flipped: bool = false
var selected_square: int = -1
var legal_move_squares: Array[int] = []
var last_move_from: int = -1
var last_move_to: int = -1
var hint_square: int = -1

# Animation state
var is_animating: bool = false
var input_blocked: bool = false  # External flag to block input (e.g., during opponent turn)
signal move_animation_finished

# Drag state
var is_dragging: bool = false
var drag_from: int = -1
var _drag_sprite: Sprite2D = null
var _original_sprite_pos: Vector2

# Board background for drawing squares and highlights
var _board_background: Node2D

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
	# Set minimum size for proper layout in containers
	custom_minimum_size = Vector2(square_size * 8, square_size * 8)

	# Enable mouse input on this Control
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Create board background that draws behind pieces
	# We use a separate Node2D for board drawing so pieces appear on top
	_board_background = Node2D.new()
	_board_background.name = "BoardBackground"
	_board_background.draw.connect(_draw_board)
	add_child(_board_background)

	# Pieces container - added after background so it renders on top
	_pieces_container = Node2D.new()
	_pieces_container.name = "Pieces"
	add_child(_pieces_container)

	_load_piece_textures()

	# Connect to resized signal for responsive sizing
	resized.connect(_on_resized)

	# Trigger initial board draw
	_board_background.queue_redraw()

	print("[ChessBoard] _ready complete. Textures loaded: ", _piece_textures.size())


## Handle container resize - adjust board to fit.
func _on_resized() -> void:
	# Calculate new square size based on available space
	var available = size
	var new_square_size = int(min(available.x, available.y) / 8.0)
	if new_square_size > 0 and new_square_size != square_size:
		set_square_size(new_square_size)


## Set a new square size and update all visuals.
func set_square_size(new_size: int) -> void:
	square_size = new_size
	custom_minimum_size = Vector2(square_size * 8, square_size * 8)

	# Update all piece positions and scales
	for sq in _piece_sprites:
		var sprite = _piece_sprites[sq]
		sprite.position = board_to_screen(sq)
		# Rescale piece to fit new square size
		if sprite.texture:
			var tex_size = sprite.texture.get_size()
			var target_size = square_size * 0.9
			var scale_factor = target_size / max(tex_size.x, tex_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)

	# Redraw board
	_board_background.queue_redraw()


## GLOBAL input handler to debug if clicks are reaching the board area at all
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos = get_local_mouse_position()
		var in_bounds = Rect2(Vector2.ZERO, size).has_point(local_pos)
		print("[ChessBoard] _input (GLOBAL): click at local=%s, size=%s, in_bounds=%s" % [local_pos, size, in_bounds])


## Toggle board visibility for debugging (press B key).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B:
			_board_background.visible = not _board_background.visible
			print("[ChessBoard] Board visible: ", _board_background.visible)
		elif event.keycode == KEY_P:
			print("[ChessBoard] Pieces container visible: ", _pieces_container.visible)
			print("[ChessBoard] Pieces count: ", _pieces_container.get_child_count())
			print("[ChessBoard] Piece sprites tracked: ", _piece_sprites.size())
			for sq in _piece_sprites:
				var sprite = _piece_sprites[sq]
				print("  Square %d: pos=%s, visible=%s, texture=%s" % [sq, sprite.position, sprite.visible, sprite.texture != null])


func _load_piece_textures() -> void:
	for fen_char in PIECE_FILES:
		var file_name = PIECE_FILES[fen_char]
		var path = "res://assets/pieces/%s.svg" % file_name
		var texture = load(path)
		if texture:
			_piece_textures[fen_char] = texture
		else:
			push_warning("Failed to load piece texture: %s" % path)


func _draw_board() -> void:
	# Draw the 8x8 grid
	for rank in range(8):
		for file in range(8):
			var is_light = (rank + file) % 2 == 0
			var color = light_color if is_light else dark_color
			var rect = Rect2(file * square_size, rank * square_size, square_size, square_size)
			_board_background.draw_rect(rect, color)

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

	# Draw hint highlight (pulsing effect would require animation, using distinct color for now)
	if hint_square >= 0:
		_draw_hint_indicator(hint_square)


func _draw_hint_indicator(square: int) -> void:
	var screen_pos = board_to_screen(square)
	# Draw a prominent border around the hint square
	var half_size = square_size / 2.0
	var rect = Rect2(
		screen_pos.x - half_size,
		screen_pos.y - half_size,
		square_size,
		square_size
	)
	# Draw thick border
	_board_background.draw_rect(rect, hint_color, false, 4.0)
	# Draw corner accents
	var corner_len = square_size * 0.25
	var corners = [
		[Vector2(rect.position.x, rect.position.y), Vector2(corner_len, 0), Vector2(0, corner_len)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-corner_len, 0), Vector2(0, corner_len)],
		[Vector2(rect.position.x, rect.end.y), Vector2(corner_len, 0), Vector2(0, -corner_len)],
		[Vector2(rect.end.x, rect.end.y), Vector2(-corner_len, 0), Vector2(0, -corner_len)]
	]
	for corner in corners:
		_board_background.draw_line(corner[0], corner[0] + corner[1], hint_color, 6.0)
		_board_background.draw_line(corner[0], corner[0] + corner[2], hint_color, 6.0)


func _draw_square_highlight(square: int, color: Color) -> void:
	var screen_pos = board_to_screen(square)
	var rect = Rect2(
		screen_pos.x - square_size / 2.0,
		screen_pos.y - square_size / 2.0,
		square_size,
		square_size
	)
	_board_background.draw_rect(rect, color)


func _draw_legal_move_indicator(square: int) -> void:
	var screen_pos = board_to_screen(square)
	var has_piece = _piece_sprites.has(square)

	if has_piece:
		# Draw a ring around capture squares
		_board_background.draw_arc(screen_pos, square_size * 0.4, 0, TAU, 32, legal_move_color, 4.0)
	else:
		# Draw a dot on empty squares
		_board_background.draw_circle(screen_pos, square_size * 0.15, legal_move_color)


## Set the board position from a FEN string.
func set_board_position(fen: String) -> void:
	print("[ChessBoard] set_board_position called with FEN: ", fen)

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
	print("[ChessBoard] Added piece '%s' at square %d, pos=%s, scale=%s" % [fen_char, square, sprite.position, sprite.scale])


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
	_board_background.queue_redraw()


func _update_piece_positions() -> void:
	for square in _piece_sprites:
		var sprite = _piece_sprites[square]
		sprite.position = board_to_screen(square)


## Set the last move highlight.
func set_last_move(from: int, to: int) -> void:
	last_move_from = from
	last_move_to = to
	_board_background.queue_redraw()


## Clear all highlights.
func clear_highlights() -> void:
	selected_square = -1
	legal_move_squares.clear()
	hint_square = -1
	_board_background.queue_redraw()


## Set hint highlight on a square (for practice mode hints).
func set_hint_highlight(square: int) -> void:
	hint_square = square
	_board_background.queue_redraw()


## Clear hint highlight.
func clear_hint_highlight() -> void:
	hint_square = -1
	_board_background.queue_redraw()


## Set selected square and legal moves.
func set_selection(square: int, legal_moves: Array[int]) -> void:
	selected_square = square
	legal_move_squares = legal_moves
	_board_background.queue_redraw()


## Clear selection.
func clear_selection() -> void:
	selected_square = -1
	legal_move_squares.clear()
	_board_background.queue_redraw()


## Handle input for square clicking and drag-and-drop.
func _gui_input(event: InputEvent) -> void:
	# SUPER DEBUG - log ANY input event
	if event is InputEventMouseButton:
		print("[ChessBoard] _gui_input received MouseButton event: pressed=%s, button=%d" % [event.pressed, event.button_index])

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Debug: Always log click attempt
		var local_pos = get_local_mouse_position()
		var global_pos = get_global_mouse_position()
		print("[ChessBoard] === CLICK DEBUG (Build %d) ===" % BUILD_NUMBER)
		print("[ChessBoard] is_animating=%s, input_blocked=%s, local_pos=%s" % [is_animating, input_blocked, local_pos])
		print("[ChessBoard] Control size=%s, square_size=%d, flipped=%s" % [size, square_size, flipped])
		print("[ChessBoard] ChessLogic FEN: %s" % ChessLogic.to_fen())
		print("[ChessBoard] side_to_move=%d (0=white, 1=black)" % ChessLogic.side_to_move)
		print("[ChessBoard] _piece_sprites keys: %s" % [_piece_sprites.keys()])

	if is_animating:
		print("[ChessBoard] Input blocked - animation in progress")
		return

	if input_blocked:
		print("[ChessBoard] Input blocked - external block active (opponent turn)")
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos = get_local_mouse_position()
			var square = screen_to_board(local_pos)

			if event.pressed:
				print("[ChessBoard] Computed square=%d from local_pos=%s" % [square, local_pos])

				# Mouse down - start drag or select
				if square >= 0:
					square_clicked.emit(square)

					var has_sprite = _piece_sprites.has(square)
					var logic_piece = ChessLogic.get_piece(square)
					print("[ChessBoard] Square %d: has_sprite=%s, ChessLogic.piece=%d" % [square, has_sprite, logic_piece])

					# First, check if we have a piece selected and this is a legal move (including captures)
					if selected_square >= 0 and square in legal_move_squares:
						# Click on legal move square (empty or capture)
						print("[ChessBoard] Moving from %d to %d" % [selected_square, square])
						move_attempted.emit(selected_square, square)
						clear_selection()
						accept_event()
					elif has_sprite:
						# Check if this piece belongs to the side to move
						var piece = ChessLogic.get_piece(square)
						var piece_color = ChessLogic.get_piece_color(piece)
						print("[ChessBoard] Piece at square %d: piece=%d, color=%d, side_to_move=%d" % [square, piece, piece_color, ChessLogic.side_to_move])
						if piece_color == ChessLogic.side_to_move:
							# Get legal moves for this piece
							var legal_moves = ChessLogic.get_legal_moves(square)
							print("[ChessBoard] Legal moves for square %d: %s" % [square, legal_moves])
							set_selection(square, legal_moves)
							# Start dragging this piece
							_start_drag(square)
							piece_selected.emit(square)
							accept_event()
						else:
							print("[ChessBoard] Piece color %d != side_to_move %d, clearing selection" % [piece_color, ChessLogic.side_to_move])
							# Clicked on opponent's piece - clear selection
							clear_selection()
					else:
						print("[ChessBoard] No piece sprite at square %d, clearing selection" % square)
						clear_selection()
				else:
					print("[ChessBoard] Invalid square (outside board)")
			else:
				# Mouse up - end drag
				if is_dragging:
					_end_drag(square)
					accept_event()

	elif event is InputEventMouseMotion and is_dragging:
		_update_drag(event.position)
		accept_event()


func _start_drag(square: int) -> void:
	if not _piece_sprites.has(square):
		return

	var sprite = _piece_sprites.get(square)
	if not sprite or not is_instance_valid(sprite):
		return

	is_dragging = true
	drag_from = square
	_drag_sprite = sprite
	_original_sprite_pos = _drag_sprite.position

	# Elevate the dragged piece
	_drag_sprite.z_index = 100

	# Immediately snap piece to cursor position for responsive dragging
	_drag_sprite.position = get_local_mouse_position()


func _update_drag(screen_pos: Vector2) -> void:
	if _drag_sprite:
		_drag_sprite.position = get_local_mouse_position()


func _end_drag(square: int) -> void:
	print("[ChessBoard] _end_drag called: square=%d, is_dragging=%s, drag_from=%d" % [square, is_dragging, drag_from])
	if not is_dragging or not _drag_sprite:
		print("[ChessBoard] _end_drag early return: is_dragging=%s, _drag_sprite=%s" % [is_dragging, _drag_sprite != null])
		is_dragging = false
		drag_from = -1
		return

	# Reset z-index
	_drag_sprite.z_index = 0

	print("[ChessBoard] _end_drag check: square=%d, legal_move_squares=%s, drag_from=%d" % [square, legal_move_squares, drag_from])
	if square >= 0 and square in legal_move_squares and square != drag_from:
		# Valid drop - attempt the move
		print("[ChessBoard] Valid drop - emitting move_attempted from %d to %d" % [drag_from, square])
		move_attempted.emit(drag_from, square)
		clear_selection()
		# Don't reset position - move_piece or animate_move will handle it
	else:
		# Invalid drop - animate back to original position
		print("[ChessBoard] Invalid drop - animating back to original position")
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(_drag_sprite, "position", _original_sprite_pos, 0.1)

	is_dragging = false
	drag_from = -1
	_drag_sprite = null


## Get the total board size.
func get_board_size() -> Vector2:
	return Vector2(square_size * 8, square_size * 8)


## Move a piece visually (immediate, no animation).
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


## Animate a piece move with smooth tweening.
func animate_move(from: int, to: int, duration: float = 0.15) -> void:
	print("[ChessBoard] animate_move called: from=%d to=%d, is_animating=%s" % [from, to, is_animating])

	if not _piece_sprites.has(from):
		print("[ChessBoard] WARNING: No sprite at 'from' square %d, _piece_sprites=%s" % [from, _piece_sprites.keys()])
		return

	if is_animating:
		print("[ChessBoard] WARNING: Already animating, skipping move")
		return

	is_animating = true

	# Remove any piece at destination
	if _piece_sprites.has(to):
		_piece_sprites[to].queue_free()
		_piece_sprites.erase(to)

	var sprite = _piece_sprites.get(from)
	if not sprite or not is_instance_valid(sprite):
		print("[ChessBoard] ERROR: Sprite at 'from' square %d is invalid" % from)
		is_animating = false
		return

	var target_pos = board_to_screen(to)

	# Elevate z-index during animation
	var original_z = sprite.z_index
	sprite.z_index = 100

	# Create tween for smooth animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", target_pos, duration)
	tween.tween_callback(func():
		if is_instance_valid(sprite):
			sprite.z_index = original_z
			_piece_sprites.erase(from)
			_piece_sprites[to] = sprite
		is_animating = false
		print("[ChessBoard] animate_move completed: from=%d to=%d, is_animating=%s" % [from, to, is_animating])
		print("[ChessBoard] After animation, _piece_sprites keys: %s" % [_piece_sprites.keys()])
		move_animation_finished.emit()
	)

	# Update last move highlight
	set_last_move(from, to)


## Handle special move animations (castling, en passant).
func animate_castle(king_from: int, king_to: int, rook_from: int, rook_to: int, duration: float = 0.15) -> void:
	if not _piece_sprites.has(king_from) or not _piece_sprites.has(rook_from):
		return

	is_animating = true

	var king_sprite = _piece_sprites[king_from]
	var rook_sprite = _piece_sprites[rook_from]

	# Elevate both pieces
	king_sprite.z_index = 100
	rook_sprite.z_index = 100

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(king_sprite, "position", board_to_screen(king_to), duration)
	tween.tween_property(rook_sprite, "position", board_to_screen(rook_to), duration)
	tween.set_parallel(false)
	tween.tween_callback(func():
		if is_instance_valid(king_sprite):
			king_sprite.z_index = 0
			_piece_sprites.erase(king_from)
			_piece_sprites[king_to] = king_sprite
		if is_instance_valid(rook_sprite):
			rook_sprite.z_index = 0
			_piece_sprites.erase(rook_from)
			_piece_sprites[rook_to] = rook_sprite
		is_animating = false
		move_animation_finished.emit()
	)

	set_last_move(king_from, king_to)


## Remove a piece from the board (for en passant capture).
func remove_piece(square: int) -> void:
	if _piece_sprites.has(square):
		_piece_sprites[square].queue_free()
		_piece_sprites.erase(square)


## Replace a piece with a different piece (for promotion).
func promote_piece(square: int, fen_char: String) -> void:
	if _piece_sprites.has(square):
		_piece_sprites[square].queue_free()
		_piece_sprites.erase(square)

	_add_piece(fen_char, square)


## Set up the board position from FEN (alias for set_board_position).
func setup_position(fen: String) -> void:
	set_board_position(fen)
	_board_background.queue_redraw()


## Refresh the board to match ChessLogic state.
func refresh_position() -> void:
	var fen = ChessLogic.to_fen()
	print("[ChessBoard] refresh_position called with FEN: %s" % fen)
	print("[ChessBoard] ChessLogic.side_to_move = %d" % ChessLogic.side_to_move)
	set_board_position(fen)
	print("[ChessBoard] After refresh, _piece_sprites keys: %s" % [_piece_sprites.keys()])
	_board_background.queue_redraw()


## Play a shake animation to indicate wrong move.
func play_wrong_move_shake() -> void:
	var original_pos = position
	var shake_amount = GameSettings.wrong_move_shake_intensity
	var total_duration = GameSettings.wrong_move_shake_duration
	var segment_duration = total_duration / 5.0

	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(shake_amount, 0), segment_duration)
	tween.tween_property(self, "position", original_pos + Vector2(-shake_amount, 0), segment_duration)
	tween.tween_property(self, "position", original_pos + Vector2(shake_amount * 0.5, 0), segment_duration)
	tween.tween_property(self, "position", original_pos + Vector2(-shake_amount * 0.5, 0), segment_duration)
	tween.tween_property(self, "position", original_pos, segment_duration)


## Flash the board with a red tint to indicate wrong move.
func flash_wrong_move() -> void:
	var flash_color = GameSettings.wrong_move_flash_color
	var flash_duration = GameSettings.wrong_move_flash_duration

	# Create a temporary overlay for the flash
	var flash_overlay = ColorRect.new()
	flash_overlay.color = flash_color
	flash_overlay.size = Vector2(square_size * 8, square_size * 8)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_overlay)

	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(flash_overlay, "modulate:a", 0.0, flash_duration)
	tween.tween_callback(flash_overlay.queue_free)
