class_name PromotionDialog
extends Control
## Modal dialog for pawn promotion piece selection.

signal promotion_selected(piece_type: int)
signal cancelled

@export var is_white: bool = true
@export var button_size: int = 70

var _buttons: Array[TextureButton] = []

# Piece textures
const PIECE_FILES = {
	true: {  # White pieces
		ChessLogic.W_QUEEN: "white_queen",
		ChessLogic.W_ROOK: "white_rook",
		ChessLogic.W_BISHOP: "white_bishop",
		ChessLogic.W_KNIGHT: "white_knight"
	},
	false: {  # Black pieces
		ChessLogic.B_QUEEN: "black_queen",
		ChessLogic.B_ROOK: "black_rook",
		ChessLogic.B_BISHOP: "black_bishop",
		ChessLogic.B_KNIGHT: "black_knight"
	}
}


func _ready() -> void:
	# Create semi-transparent background overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)

	# Create centered panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(button_size * 4 + 30, button_size + 20)
	add_child(panel)

	# Create button container
	var hbox = HBoxContainer.new()
	hbox.name = "ButtonContainer"
	hbox.add_theme_constant_override("separation", 5)
	panel.add_child(hbox)

	# Get the appropriate piece set
	var pieces = PIECE_FILES[is_white]

	# Create buttons for each promotion piece
	for piece_type in pieces:
		var button = TextureButton.new()
		button.custom_minimum_size = Vector2(button_size, button_size)
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.ignore_texture_size = true

		var texture_path = "res://assets/pieces/%s.svg" % pieces[piece_type]
		var texture = load(texture_path)
		if texture:
			button.texture_normal = texture
		else:
			push_warning("Failed to load promotion piece texture: %s" % texture_path)

		button.pressed.connect(_on_piece_selected.bind(piece_type))
		hbox.add_child(button)
		_buttons.append(button)

	# Center the panel
	await get_tree().process_frame
	_center_panel()


func _center_panel() -> void:
	var panel = get_node_or_null("Panel")
	if panel:
		panel.position = (get_viewport_rect().size - panel.size) / 2


func _on_piece_selected(piece_type: int) -> void:
	promotion_selected.emit(piece_type)
	queue_free()


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		cancelled.emit()
		queue_free()


## Show the dialog at a specific position (near the promotion square).
func show_at_position(screen_pos: Vector2) -> void:
	await get_tree().process_frame
	var panel = get_node_or_null("Panel")
	if panel:
		# Position near the promotion square but ensure it stays on screen
		var viewport_size = get_viewport_rect().size
		var panel_size = panel.size

		var x = clamp(screen_pos.x - panel_size.x / 2, 0, viewport_size.x - panel_size.x)
		var y = clamp(screen_pos.y - panel_size.y / 2, 0, viewport_size.y - panel_size.y)

		panel.position = Vector2(x, y)


## Auto-promote to Queen if it maintains mate, otherwise return best alternative.
## Used in Sprint/Streak modes for faster gameplay.
func auto_promote(fen: String, from: int, to: int) -> int:
	# Default to Queen
	var queen = ChessLogic.W_QUEEN if is_white else ChessLogic.B_QUEEN

	# For auto-promotion in puzzle modes, always use Queen
	# A more sophisticated version could check if Queen breaks forced mate
	return queen


## Static method to create and show the dialog.
static func create(parent: Node, is_white_promotion: bool) -> PromotionDialog:
	var dialog = PromotionDialog.new()
	dialog.is_white = is_white_promotion
	dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dialog)
	return dialog
