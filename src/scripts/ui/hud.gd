extends CanvasLayer

signal stop_requested

@onready var _distance_label: Label = $DistanceLabel
@onready var _notification_area: Control = $NotificationArea
@onready var _notification_icon: Button = $NotificationArea/NotificationIcon
@onready var _willpower_bar: ProgressBar = $NotificationArea/WillpowerBar
@onready var _stop_button: Button = $StopButton

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	NotificationManager.notification_arrived.connect(_on_notification_arrived)
	NotificationManager.phone_dismissed.connect(_on_phone_dismissed)
	NotificationManager.phone_opened.connect(_on_phone_opened)
	_notification_icon.pressed.connect(_on_notification_icon_pressed)
	_stop_button.pressed.connect(_on_stop_button_pressed)
	_willpower_bar.max_value = NotificationManager.WILLPOWER_MAX_MVP

func _process(_delta: float) -> void:
	if NotificationManager.willpower_active:
		_willpower_bar.value = NotificationManager.willpower_remaining

func _on_score_changed(new_score: int) -> void:
	_distance_label.text = "%d m" % new_score

func _on_notification_arrived(_notification) -> void:
	_willpower_bar.value = NotificationManager.WILLPOWER_MAX_MVP
	_notification_area.visible = true

func _on_phone_opened(_voluntary: bool) -> void:
	_notification_area.visible = false

func _on_phone_dismissed() -> void:
	_notification_area.visible = false

func _on_notification_icon_pressed() -> void:
	NotificationManager.request_check_phone()

func _on_stop_button_pressed() -> void:
	stop_requested.emit()
