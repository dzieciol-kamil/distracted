extends Node

signal hazard_spawned(node: Node3D)
signal hazard_cleared(node: Node3D)

const SPAWN_X_BUFFER: float = 2.0

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
	if GameState.current_zone == null:
		return
	if GameState.distance >= _next_spawn_distance:
		_spawn_hazard()
		_schedule_next_spawn()

func _spawn_hazard() -> void:
	var entry = _pick_hazard_entry()
	if entry == null or entry.scene == null:
		return
	var hazard: Node3D = entry.scene.instantiate()
	var lookahead: float = randf_range(entry.spawn_lookahead_min, entry.spawn_lookahead_max)

	if entry.is_lane_obstacle:
		var lane_count: int = GameState.current_zone.lane_count
		var lane_x: float = _lane_x_for_spawn(lane_count)
		hazard.position = Vector3(lane_x, 0.5, _player.global_position.z - lookahead)
	else:
		var spawn_side: float = 1.0 if randf() < 0.5 else -1.0
		var path_half_width: float = GameState.current_zone.path_width / 2.0
		var spawn_x: float = (path_half_width + SPAWN_X_BUFFER) * spawn_side
		hazard.position = Vector3(spawn_x, 0.75, _player.global_position.z - lookahead)

	_container.add_child(hazard)
	hazard.cleared.connect(_on_hazard_cleared)
	hazard_spawned.emit(hazard)

func _pick_hazard_entry():
	var pool = GameState.current_zone.hazard_pool
	if pool.is_empty():
		return null
	var total: int = 0
	for entry in pool:
		total += entry.weight
	if total <= 0:
		return pool[0]
	var roll: int = randi() % total
	var acc: int = 0
	for entry in pool:
		acc += entry.weight
		if roll < acc:
			return entry
	return pool[0]

func _on_hazard_cleared(node: Node3D) -> void:
	hazard_cleared.emit(node)

func _schedule_next_spawn() -> void:
	if GameState.current_zone == null:
		return
	var zone = GameState.current_zone
	var interval: float = randf_range(zone.spawn_interval_min, zone.spawn_interval_max)
	_next_spawn_distance = GameState.distance + interval

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		stop()

func _lane_x_for_spawn(lane_count: int) -> float:
	if lane_count == 1:
		return 0.0
	var path_width: float = GameState.current_zone.path_width
	var lane_width: float = path_width / float(lane_count)
	var lane: int = randi() % lane_count
	return (float(lane) - float(lane_count - 1) / 2.0) * lane_width
