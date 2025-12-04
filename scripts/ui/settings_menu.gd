class_name SettingsMenu
extends Control
## Settings menu with toggle switches and sliders.

signal back_requested()
signal scene_push_requested(scene_name: String)

# Gameplay settings
@onready var legal_moves_check: CheckButton = $ScrollContainer/VBoxContainer/GameplaySection/ShowLegalMovesRow/CheckButton
@onready var auto_flip_check: CheckButton = $ScrollContainer/VBoxContainer/GameplaySection/AutoFlipRow/CheckButton
@onready var auto_queen_check: CheckButton = $ScrollContainer/VBoxContainer/GameplaySection/AutoQueenRow/CheckButton

# Audio settings
@onready var sound_check: CheckButton = $ScrollContainer/VBoxContainer/AudioSection/SoundRow/CheckButton
@onready var music_check: CheckButton = $ScrollContainer/VBoxContainer/AudioSection/MusicRow/CheckButton

# Animation settings
@onready var anim_speed_slider: HSlider = $ScrollContainer/VBoxContainer/AnimationSection/SpeedRow/SpeedSlider
@onready var anim_speed_label: Label = $ScrollContainer/VBoxContainer/AnimationSection/SpeedRow/SpeedLabel

# About section
@onready var licenses_btn: Button = $ScrollContainer/VBoxContainer/AboutSection/LicensesButton
@onready var version_label: Label = $ScrollContainer/VBoxContainer/AboutSection/VersionLabel

@onready var back_btn: Button = $BackButton


func _ready() -> void:
	_load_settings()
	_connect_signals()


func _load_settings() -> void:
	# Load from UserData
	if legal_moves_check:
		legal_moves_check.button_pressed = UserData.get_setting("show_legal_moves", true)
	if auto_flip_check:
		auto_flip_check.button_pressed = UserData.get_setting("auto_flip_board", true)
	if auto_queen_check:
		auto_queen_check.button_pressed = UserData.get_setting("auto_promote_queen", false)
	if sound_check:
		sound_check.button_pressed = UserData.get_setting("sound_enabled", true)
	if music_check:
		music_check.button_pressed = UserData.get_setting("music_enabled", true)
	if anim_speed_slider:
		anim_speed_slider.value = UserData.get_setting("animation_speed", 1.0)
		_update_speed_label(anim_speed_slider.value)


func _connect_signals() -> void:
	if legal_moves_check:
		legal_moves_check.toggled.connect(func(pressed): _on_setting_changed("show_legal_moves", pressed))
	if auto_flip_check:
		auto_flip_check.toggled.connect(func(pressed): _on_setting_changed("auto_flip_board", pressed))
	if auto_queen_check:
		auto_queen_check.toggled.connect(func(pressed): _on_setting_changed("auto_promote_queen", pressed))
	if sound_check:
		sound_check.toggled.connect(func(pressed): _on_setting_changed("sound_enabled", pressed))
	if music_check:
		music_check.toggled.connect(func(pressed): _on_setting_changed("music_enabled", pressed))
	if anim_speed_slider:
		anim_speed_slider.value_changed.connect(_on_speed_changed)
	if licenses_btn:
		licenses_btn.pressed.connect(_on_licenses_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)


func _on_setting_changed(key: String, value: Variant) -> void:
	UserData.update_setting(key, value)


func _on_speed_changed(value: float) -> void:
	UserData.update_setting("animation_speed", value)
	_update_speed_label(value)


func _update_speed_label(value: float) -> void:
	if anim_speed_label:
		if value <= 0.15:
			anim_speed_label.text = "Instant"
		else:
			anim_speed_label.text = "%.1fx" % value


func _on_licenses_pressed() -> void:
	scene_push_requested.emit("licenses_screen")


func _on_back_pressed() -> void:
	back_requested.emit()
