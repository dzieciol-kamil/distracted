extends Control

@onready var score_label: Label = $VBox/ScoreLabel
@onready var retry_button: Button = $VBox/RetryButton
@onready var menu_button: Button = $VBox/MenuButton

func _ready() -> void:
	score_label.text = "Distance: %dm" % int(GameState.distance)
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_retry_pressed() -> void:
	GameState.reset()
	SceneManager.go_to("game")

func _on_menu_pressed() -> void:
	GameState.reset()
	SceneManager.go_to("main_menu")
