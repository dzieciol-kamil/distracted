extends CanvasLayer

const SLIDE_IN_DURATION: float = 0.3
const SLIDE_OUT_DURATION: float = 0.2
const FRAME_HEIGHT: float = 675.0

@onready var _frame: ColorRect = $PhoneFrame
@onready var _sender_label: Label = $PhoneFrame/NotificationCard/SenderLabel
@onready var _text_label: Label = $PhoneFrame/NotificationCard/TextLabel
@onready var _dismiss_button: Button = $PhoneFrame/DismissButton

var _tween: Tween

func _ready() -> void:
	NotificationManager.phone_opened.connect(_on_phone_opened)
	NotificationManager.phone_dismissed.connect(_on_phone_dismissed)
	NotificationManager.notification_arrived.connect(_on_notification_arrived)
	_dismiss_button.pressed.connect(_on_dismiss_pressed)
	_frame.offset_top = -FRAME_HEIGHT
	_frame.offset_bottom = 0.0

func _on_notification_arrived(notification) -> void:
	_sender_label.text = notification.sender
	_text_label.text = notification.text

func _on_phone_opened(_voluntary: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_frame, "offset_top", 0.0, SLIDE_IN_DURATION)
	_tween.parallel().tween_property(_frame, "offset_bottom", FRAME_HEIGHT, SLIDE_IN_DURATION)

func _on_phone_dismissed() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_frame, "offset_top", -FRAME_HEIGHT, SLIDE_OUT_DURATION)
	_tween.parallel().tween_property(_frame, "offset_bottom", 0.0, SLIDE_OUT_DURATION)

func _on_dismiss_pressed() -> void:
	NotificationManager.dismiss_current()
