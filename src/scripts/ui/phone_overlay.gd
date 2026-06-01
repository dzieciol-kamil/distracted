extends CanvasLayer

const SLIDE_DURATION: float = 0.4
const HIDDEN_Y: float = -900.0

@onready var phone_panel: Panel = $PhonePanel
@onready var app_name_label: Label = $PhonePanel/AppBar/AppName
@onready var notification_text: Label = $PhonePanel/NotificationText
@onready var dismiss_button: Button = $PhonePanel/DismissButton

func _ready() -> void:
	phone_panel.position.y = HIDDEN_Y
	GameState.phase_changed.connect(_on_phase_changed)
	NotificationManager.notification_arrived.connect(_on_notification_arrived)
	dismiss_button.pressed.connect(_on_dismiss_pressed)

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.PHONE:
		_slide_in()
	elif phone_panel.position.y > HIDDEN_Y + 1.0:
		_slide_out()

func _on_notification_arrived(notification_id: String) -> void:
	pass  # text is set when phase switches to PHONE

func _slide_in() -> void:
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(phone_panel, "position:y", 0.0, SLIDE_DURATION)

func _slide_out() -> void:
	var tween: Tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(phone_panel, "position:y", HIDDEN_Y, SLIDE_DURATION)

func _on_dismiss_pressed() -> void:
	NotificationManager.dismiss_current()
