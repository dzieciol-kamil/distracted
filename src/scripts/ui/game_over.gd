extends Control

@onready var _distance_label: Label = $VBox/DistanceLabel
@onready var _phone_label: Label = $VBox/PhoneLabel
@onready var _retry_button: Button = $VBox/RetryButton

func _ready() -> void:
	_distance_label.text = "Przeszedłeś %d m." % int(GameState.distance)
	_phone_label.text = "Patrzyłeś na telefon %d%% czasu." % int(round(GameState.get_phone_percentage()))
	_retry_button.pressed.connect(_on_retry_pressed)
	_retry_button.grab_focus()

func _on_retry_pressed() -> void:
	SceneManager.change_to("res://scenes/game/game.tscn")
