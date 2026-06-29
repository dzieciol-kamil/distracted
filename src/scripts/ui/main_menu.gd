extends Control

@onready var _start_button: Button = $VBox/StartButton

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus()
	if "--qa-gameplay-smoke" in OS.get_cmdline_user_args():
		call_deferred("_on_start_pressed")

func _on_start_pressed() -> void:
	SceneManager.change_to("res://scenes/game/game.tscn")
