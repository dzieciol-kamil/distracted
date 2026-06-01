extends Control

@onready var play_button: Button = $VBox/PlayButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	SceneManager.go_to("game")
