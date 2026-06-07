extends Control

@onready var _start_button: Button = $VBox/StartButton
@onready var _start_suburb_button: Button = $VBox/StartSuburbButton
@onready var _start_town_button: Button = $VBox/StartTownButton
@onready var _start_city_button: Button = $VBox/StartCityButton

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed.bind(GameState.ZoneIndex.VILLAGE))
	_start_suburb_button.pressed.connect(_on_start_pressed.bind(GameState.ZoneIndex.SUBURB))
	_start_town_button.pressed.connect(_on_start_pressed.bind(GameState.ZoneIndex.TOWN))
	_start_city_button.pressed.connect(_on_start_pressed.bind(GameState.ZoneIndex.CITY))
	_start_button.grab_focus()

func _on_start_pressed(zone: GameState.ZoneIndex) -> void:
	GameState.start_zone = zone
	SceneManager.change_to("res://scenes/game/game.tscn")
