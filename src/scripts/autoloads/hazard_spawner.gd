extends Node

signal hazard_spawned(node: Node3D)
signal hazard_cleared(node: Node3D)

const TRACTOR_SCENE: PackedScene = preload("res://scenes/hazards/tractor.tscn")
const SPAWN_INTERVAL_MIN: float = 25.0
const SPAWN_INTERVAL_MAX: float = 40.0
const SPAWN_LOOKAHEAD_MIN: float = 12.0
const SPAWN_LOOKAHEAD_MAX: float = 15.0
const SPAWN_X: float = -3.0

var _container: Node3D = null
var _player: Node3D = null
var _next_spawn_distance: float = 0.0
var _running: bool = false

func _ready() -> void:
	GameState.phase_changed.connect(_on_phase_changed)

func bind_scene(container: Node3D, player: Node3D) -> void:
	_container = container
	_player = player

func start() -> void:
	_running = true
	_schedule_next_spawn()

func stop() -> void:
	_running = false

func _process(_delta: float) -> void:
	if not _running:
		return
	if _container == null or _player == null:
		return
	if GameState.distance >= _next_spawn_distance:
		_spawn_tractor()
		_schedule_next_spawn()

func _spawn_tractor() -> void:
	var tractor: Node3D = TRACTOR_SCENE.instantiate()
	var lookahead: float = randf_range(SPAWN_LOOKAHEAD_MIN, SPAWN_LOOKAHEAD_MAX)
	tractor.position = Vector3(SPAWN_X, 0.75, _player.global_position.z - lookahead)
	_container.add_child(tractor)
	tractor.cleared.connect(_on_tractor_cleared)
	hazard_spawned.emit(tractor)

func _on_tractor_cleared(node: Node3D) -> void:
	hazard_cleared.emit(node)

func _schedule_next_spawn() -> void:
	_next_spawn_distance = GameState.distance + randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		stop()
