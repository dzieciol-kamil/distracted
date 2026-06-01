extends Node

signal hazard_spawned(hazard: Node3D)

const SPAWN_DISTANCE: float = -80.0
const DESPAWN_DISTANCE: float = 15.0

var _active_hazards: Array[Node3D] = []
var _spawn_timer: Timer
var _player: Node3D

func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)
	GameState.phase_changed.connect(_on_phase_changed)

func start(player: Node3D) -> void:
	_player = player
	_spawn_timer.wait_time = _get_spawn_interval()
	_spawn_timer.start()

func stop() -> void:
	_spawn_timer.stop()

func _process(_delta: float) -> void:
	if not _player:
		return
	for hazard in _active_hazards.duplicate():
		if hazard.global_position.z > _player.global_position.z + DESPAWN_DISTANCE:
			_active_hazards.erase(hazard)
			hazard.queue_free()

func _on_spawn_tick() -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		return
	_spawn_hazard()
	_spawn_timer.wait_time = _get_spawn_interval()

func _spawn_hazard() -> void:
	pass  # implemented per zone in feature issues

func _get_spawn_interval() -> float:
	match GameState.zone:
		GameState.Zone.VILLAGE:
			return 4.0
		GameState.Zone.SUBURB:
			return 2.5
		GameState.Zone.TOWN:
			return 1.5
		_:
			return 0.8

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		stop()
