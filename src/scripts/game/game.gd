extends Node3D

@onready var _world_container: Node3D = $WorldContainer
@onready var _hazard_container: Node3D = $WorldContainer/HazardContainer
@onready var _player: Node3D = $Player
@onready var _stop_controller: Node = $StopController

func _ready() -> void:
	GameState.reset_metrics()
	HazardSpawner.bind_scene(_hazard_container, _player)
	HazardSpawner.start()
	NotificationManager.start()
	_stop_controller.bind_player(_player)
	_player.collided_with_hazard.connect(_on_player_collided)

func _on_player_collided() -> void:
	GameState.set_phase(GameState.GamePhase.GAME_OVER)
