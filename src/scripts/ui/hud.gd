extends CanvasLayer

signal stop_hold_started
signal stop_hold_released

@onready var _distance_label: Label = $DistanceLabel
@onready var _notification_area: Button = $NotificationArea
@onready var _notification_icon: Label = $NotificationArea/NotificationIcon
@onready var _willpower_bar: ProgressBar = $NotificationArea/WillpowerBar
@onready var _stop_button: Button = $StopButton

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	NotificationManager.notification_arrived.connect(_on_notification_arrived)
	NotificationManager.phone_dismissed.connect(_on_phone_dismissed)
	NotificationManager.phone_opened.connect(_on_phone_opened)
	_notification_area.pressed.connect(_on_notification_area_pressed)
	_stop_button.button_down.connect(_on_stop_button_down)
	_stop_button.button_up.connect(_on_stop_button_up)

func _process(_delta: float) -> void:
	if NotificationManager.willpower_active:
		_willpower_bar.value = NotificationManager.willpower_remaining

func _on_score_changed(new_score: int) -> void:
	_distance_label.text = "%d m" % new_score

func _on_notification_arrived(_notification) -> void:
	var max_value: float = NotificationManager.willpower_remaining
	_willpower_bar.max_value = max_value
	_willpower_bar.value = max_value
	_notification_area.visible = true

func _on_phone_opened(_voluntary: bool) -> void:
	_notification_area.visible = false

func _on_phone_dismissed() -> void:
	_notification_area.visible = false

func _on_notification_area_pressed() -> void:
	NotificationManager.request_check_phone()

func _on_stop_button_down() -> void:
	stop_hold_started.emit()

func _on_stop_button_up() -> void:
	stop_hold_released.emit()
