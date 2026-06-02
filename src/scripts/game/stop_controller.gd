extends Node

const PHONE_STOP_TIMEOUT: float = 1.0

var _player: Node3D = null
var _active_hazards: Array[Node] = []
var _phone_timer: Timer

func _ready() -> void:
	_phone_timer = Timer.new()
	_phone_timer.one_shot = true
	_phone_timer.timeout.connect(_on_phone_timer_elapsed)
	add_child(_phone_timer)
	HazardSpawner.hazard_spawned.connect(_on_hazard_spawned)
	HazardSpawner.hazard_cleared.connect(_on_hazard_cleared)
	GameState.phase_changed.connect(_on_phase_changed)

func bind_player(player: Node3D) -> void:
	_player = player
	if not _player.stop_pressed.is_connected(_on_stop_pressed):
		_player.stop_pressed.connect(_on_stop_pressed)

func _on_stop_pressed() -> void:
	if _player == null:
		return
	_player.set_stopped()
	if GameState.phase == GameState.GamePhase.PHONE:
		_phone_timer.start(PHONE_STOP_TIMEOUT)
	# in ROAD mode auto-resume happens via _on_hazard_cleared

func _on_hazard_spawned(node: Node) -> void:
	_active_hazards.append(node)

func _on_hazard_cleared(node: Node) -> void:
	_active_hazards.erase(node)
	if _player == null:
		return
	if GameState.phase == GameState.GamePhase.ROAD and _player.walk_state == _player.WalkState.STOPPED and _active_hazards.is_empty():
		_player.set_walking()

func _on_phone_timer_elapsed() -> void:
	if _player == null:
		return
	if _player.walk_state == _player.WalkState.STOPPED:
		_player.set_walking()

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.ROAD:
		# phone closed: if no hazards active, auto-resume; if hazards active, stay stopped until cleared
		if _player == null:
			return
		if _player.walk_state == _player.WalkState.STOPPED and _active_hazards.is_empty():
			_player.set_walking()
	elif new_phase == GameState.GamePhase.GAME_OVER:
		_phone_timer.stop()
