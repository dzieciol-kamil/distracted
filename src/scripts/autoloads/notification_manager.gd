extends Node

signal notification_arrived(notification_id: String)
signal notification_dismissed

const DATA_PATH: String = "res://data/notifications/notifications.json"

var current_willpower_time: float = 5.0
var _queue: Array = []
var _all: Array = []
var _interval_timer: Timer
var _active_notification: Dictionary = {}

func _ready() -> void:
	_load_data()
	_interval_timer = Timer.new()
	_interval_timer.one_shot = true
	_interval_timer.timeout.connect(_on_interval_timeout)
	add_child(_interval_timer)
	GameState.zone_changed.connect(_on_zone_changed)
	GameState.phase_changed.connect(_on_phase_changed)

func start() -> void:
	_queue = _all.duplicate()
	_queue.shuffle()
	_schedule_next()

func stop() -> void:
	_interval_timer.stop()

func dismiss_current() -> void:
	if _active_notification.is_empty():
		return
	_active_notification = {}
	notification_dismissed.emit()
	if GameState.phase == GameState.GamePhase.PHONE:
		GameState.set_phase(GameState.GamePhase.ROAD)
	_schedule_next()

func _load_data() -> void:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if not file:
		push_error("NotificationManager: cannot open " + DATA_PATH)
		return
	var json: JSON = JSON.new()
	json.parse(file.get_as_text())
	_all = json.get_data()

func _schedule_next() -> void:
	var interval: float = GameState.ZONE_NOTIFICATION_INTERVALS[GameState.zone]
	_interval_timer.wait_time = interval
	_interval_timer.start()

func _on_interval_timeout() -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		return
	if _queue.is_empty():
		_queue = _all.duplicate()
		_queue.shuffle()
	_active_notification = _queue.pop_back()
	current_willpower_time = _get_willpower_time()
	notification_arrived.emit(_active_notification.get("id", ""))

func _get_willpower_time() -> float:
	var base: float = 5.0
	var zone_index: int = GameState.zone as int
	return maxf(base - zone_index * 0.8, 1.5)

func _on_zone_changed(_zone: GameState.Zone) -> void:
	pass

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		stop()
