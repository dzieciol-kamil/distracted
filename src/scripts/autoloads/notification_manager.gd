extends Node

signal notification_arrived(notification)
signal willpower_expired
signal phone_opened(voluntary: bool)
signal phone_dismissed

const NOTIFICATION_PATHS: Array[String] = [
	"res://resources/notifications/mama_zjadles.tres",
]
const SAFE_WINDOW_MIN: float = 5.0
const SAFE_WINDOW_MAX: float = 8.0
const WILLPOWER_MAX_MVP: float = 3.0

var willpower_remaining: float = 0.0
var willpower_active: bool = false
var current_notification = null

var _all: Array = []
var _interval_timer: Timer
var _running: bool = false

func _ready() -> void:
	_load_pool()
	_interval_timer = Timer.new()
	_interval_timer.one_shot = true
	_interval_timer.timeout.connect(_on_safe_window_elapsed)
	add_child(_interval_timer)
	GameState.phase_changed.connect(_on_phase_changed)
	call_deferred("start")

func start() -> void:
	_running = true
	_schedule_next_safe_window()

func stop() -> void:
	_running = false
	_interval_timer.stop()
	willpower_active = false
	current_notification = null

func request_check_phone() -> void:
	if not willpower_active:
		return
	_open_phone(true)

func dismiss_current() -> void:
	if current_notification == null:
		return
	current_notification = null
	phone_dismissed.emit()
	if GameState.phase == GameState.GamePhase.PHONE:
		GameState.set_phase(GameState.GamePhase.ROAD)
	_schedule_next_safe_window()

func _process(delta: float) -> void:
	if not willpower_active:
		return
	willpower_remaining -= delta
	if willpower_remaining <= 0.0:
		willpower_active = false
		willpower_remaining = 0.0
		willpower_expired.emit()
		_open_phone(false)

func _load_pool() -> void:
	for path in NOTIFICATION_PATHS:
		var n = load(path)
		if n == null:
			push_error("NotificationManager: cannot load " + path)
			continue
		_all.append(n)

func _schedule_next_safe_window() -> void:
	if not _running:
		return
	var interval: float = randf_range(SAFE_WINDOW_MIN, SAFE_WINDOW_MAX)
	_interval_timer.wait_time = interval
	_interval_timer.start()

func _on_safe_window_elapsed() -> void:
	if GameState.phase != GameState.GamePhase.ROAD:
		return
	if _all.is_empty():
		return
	current_notification = _all.pick_random()
	willpower_remaining = WILLPOWER_MAX_MVP
	willpower_active = true
	notification_arrived.emit(current_notification)

func _open_phone(voluntary: bool) -> void:
	if current_notification == null:
		return
	willpower_active = false
	GameState.set_phase(GameState.GamePhase.PHONE)
	phone_opened.emit(voluntary)

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		stop()
