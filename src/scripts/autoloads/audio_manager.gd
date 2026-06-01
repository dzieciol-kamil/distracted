extends Node

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	add_child(_sfx_player)

func play_music(stream: AudioStream) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func play_sfx(stream: AudioStream) -> void:
	_sfx_player.stream = stream
	_sfx_player.play()

func set_music_volume(linear: float) -> void:
	_music_player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0))

func set_sfx_volume(linear: float) -> void:
	_sfx_player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0))
