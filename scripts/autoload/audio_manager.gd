class_name AudioManagerClass
extends Node
## Manages all game audio playback with volume control and mute functionality.

# Audio players for each sound type
var player_move: AudioStreamPlayer
var player_capture: AudioStreamPlayer
var player_check: AudioStreamPlayer
var player_success: AudioStreamPlayer
var player_failure: AudioStreamPlayer
var player_tick: AudioStreamPlayer

# Audio streams (preloaded)
var stream_move: AudioStream
var stream_capture: AudioStream
var stream_check: AudioStream
var stream_success: AudioStream
var stream_failure: AudioStream
var stream_tick: AudioStream

# Volume control (0.0 to 1.0)
var volume: float = 1.0:
	set(value):
		volume = clamp(value, 0.0, 1.0)
		_update_all_volumes()

# Mute state
var muted: bool = false:
	set(value):
		muted = value
		_update_all_volumes()

# Audio bus name
const BUS_NAME = "Master"


func _ready() -> void:
	_create_players()
	_load_audio_assets()


func _create_players() -> void:
	player_move = AudioStreamPlayer.new()
	player_capture = AudioStreamPlayer.new()
	player_check = AudioStreamPlayer.new()
	player_success = AudioStreamPlayer.new()
	player_failure = AudioStreamPlayer.new()
	player_tick = AudioStreamPlayer.new()

	add_child(player_move)
	add_child(player_capture)
	add_child(player_check)
	add_child(player_success)
	add_child(player_failure)
	add_child(player_tick)


func _load_audio_assets() -> void:
	# Try to load audio assets if they exist
	var audio_path = "res://assets/audio/"

	if ResourceLoader.exists(audio_path + "move.wav"):
		stream_move = load(audio_path + "move.wav")
		player_move.stream = stream_move

	if ResourceLoader.exists(audio_path + "capture.wav"):
		stream_capture = load(audio_path + "capture.wav")
		player_capture.stream = stream_capture

	if ResourceLoader.exists(audio_path + "check.wav"):
		stream_check = load(audio_path + "check.wav")
		player_check.stream = stream_check

	if ResourceLoader.exists(audio_path + "success.wav"):
		stream_success = load(audio_path + "success.wav")
		player_success.stream = stream_success

	if ResourceLoader.exists(audio_path + "failure.wav"):
		stream_failure = load(audio_path + "failure.wav")
		player_failure.stream = stream_failure

	if ResourceLoader.exists(audio_path + "tick.wav"):
		stream_tick = load(audio_path + "tick.wav")
		player_tick.stream = stream_tick


func _update_all_volumes() -> void:
	var effective_volume = 0.0 if muted else volume
	var db = linear_to_db(effective_volume)

	if player_move:
		player_move.volume_db = db
	if player_capture:
		player_capture.volume_db = db
	if player_check:
		player_check.volume_db = db
	if player_success:
		player_success.volume_db = db
	if player_failure:
		player_failure.volume_db = db
	if player_tick:
		player_tick.volume_db = db


## Play piece placement sound.
func play_move() -> void:
	if player_move and player_move.stream and not muted:
		player_move.play()


## Play capture sound.
func play_capture() -> void:
	if player_capture and player_capture.stream and not muted:
		player_capture.play()


## Play check warning sound.
func play_check() -> void:
	if player_check and player_check.stream and not muted:
		player_check.play()


## Play puzzle success sound.
func play_success() -> void:
	if player_success and player_success.stream and not muted:
		player_success.play()


## Play wrong move sound.
func play_failure() -> void:
	if player_failure and player_failure.stream and not muted:
		player_failure.play()


## Play timer tick sound.
func play_tick() -> void:
	if player_tick and player_tick.stream and not muted:
		player_tick.play()


## Set volume level (0.0 to 1.0).
func set_volume(new_volume: float) -> void:
	volume = new_volume


## Toggle mute state.
func toggle_mute() -> void:
	muted = not muted


## Check if audio is enabled.
func is_enabled() -> bool:
	return not muted and volume > 0.0
