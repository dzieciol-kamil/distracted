extends Node3D

@onready var _world_container: Node3D = $WorldContainer
@onready var _hazard_container: Node3D = $WorldContainer/HazardContainer
@onready var _player: Node3D = $Player
@onready var _stop_controller: Node = $StopController
@onready var _hud: CanvasLayer = $HUD

func _ready() -> void:
	GameState.reset_metrics()
	HazardSpawner.bind_scene(_hazard_container, _player)
	HazardSpawner.start()
	NotificationManager.start()
	_stop_controller.bind_player(_player)
	_player.collided_with_hazard.connect(_on_player_collided)
	_hud.stop_hold_started.connect(_on_ui_stop_hold_started)
	_hud.stop_hold_released.connect(_on_ui_stop_hold_released)

func _on_ui_stop_hold_started() -> void:
	_player.set_stopped()

func _on_ui_stop_hold_released() -> void:
	_player.set_walking()

func _on_player_collided() -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		return
	GameState.set_phase(GameState.GamePhase.GAME_OVER)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
