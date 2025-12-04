class_name LicensesScreen
extends Control
## Licenses screen displaying open source attributions for GPL compliance.

signal back_requested()

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var licenses_container: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var back_btn: Button = $BackButton

# License data
const LICENSES = [
	{
		"name": "Stockfish",
		"description": "Chess engine used for puzzle analysis",
		"license": "GPLv3",
		"url": "https://stockfishchess.org",
		"source_url": "https://github.com/official-stockfish/Stockfish"
	},
	{
		"name": "Lichess Puzzle Database",
		"description": "Chess puzzles sourced from Lichess.org",
		"license": "CC0 (Public Domain)",
		"url": "https://database.lichess.org"
	},
	{
		"name": "Godot Engine",
		"description": "Game engine",
		"license": "MIT",
		"url": "https://godotengine.org"
	},
	{
		"name": "godot-sqlite",
		"description": "SQLite plugin for Godot",
		"license": "MIT",
		"url": "https://github.com/2shady4u/godot-sqlite"
	}
]

# GPL v3 license text (abbreviated, with link to full text)
const GPL_NOTICE = """This application uses Stockfish, which is licensed under
the GNU General Public License version 3 (GPLv3).

Under the GPLv3, you have the following rights:
- Use the software for any purpose
- Study how the software works and modify it
- Redistribute copies of the software
- Distribute copies of your modified versions

The full GPL v3 license text is available at:
https://www.gnu.org/licenses/gpl-3.0.txt

Stockfish source code is available at:
https://github.com/official-stockfish/Stockfish"""


func _ready() -> void:
	_build_licenses_ui()
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)


func _build_licenses_ui() -> void:
	if not licenses_container:
		return

	# Add each license entry
	for license_info in LICENSES:
		var entry = _create_license_entry(license_info)
		licenses_container.add_child(entry)

	# Add GPL notice section
	var gpl_section = _create_gpl_section()
	licenses_container.add_child(gpl_section)


func _create_license_entry(info: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)

	# Name and license type
	var name_label = Label.new()
	name_label.text = "%s (%s)" % [info.name, info.license]
	name_label.add_theme_font_size_override("font_size", 18)
	container.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = info.description
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	desc_label.add_theme_font_size_override("font_size", 14)
	container.add_child(desc_label)

	# URL
	var url_label = Label.new()
	url_label.text = info.url
	url_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
	url_label.add_theme_font_size_override("font_size", 14)
	container.add_child(url_label)

	# Source URL if available (for GPL compliance)
	if info.has("source_url"):
		var source_label = Label.new()
		source_label.text = "Source: %s" % info.source_url
		source_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
		source_label.add_theme_font_size_override("font_size", 14)
		container.add_child(source_label)

	# Separator
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 15)
	container.add_child(separator)

	return container


func _create_gpl_section() -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	# Section header
	var header = Label.new()
	header.text = "GNU General Public License v3"
	header.add_theme_font_size_override("font_size", 20)
	container.add_child(header)

	# GPL notice text
	var notice_label = RichTextLabel.new()
	notice_label.text = GPL_NOTICE
	notice_label.custom_minimum_size = Vector2(0, 200)
	notice_label.bbcode_enabled = false
	notice_label.scroll_active = false
	notice_label.fit_content = true
	notice_label.add_theme_font_size_override("normal_font_size", 14)
	container.add_child(notice_label)

	return container


func _on_back_pressed() -> void:
	back_requested.emit()
