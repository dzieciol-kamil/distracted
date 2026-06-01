extends CanvasLayer

@onready var score_label: Label = $TopBar/ScoreLabel
@onready var zone_label: Label = $TopBar/ZoneLabel
@onready var willpower_bar: ProgressBar = $WillpowerBar

const ZONE_NAMES: Array[String] = ["Village", "Suburb", "Town", "City"]

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.zone_changed.connect(_on_zone_changed)
	NotificationManager.notification_arrived.connect(_on_notification_arrived)
	NotificationManager.notification_dismissed.connect(_on_notification_dismissed)

func _process(_delta: float) -> void:
	if willpower_bar.visible and GameState.phase == GameState.GamePhase.ROAD:
		var elapsed: float = NotificationManager.current_willpower_time - willpower_bar.value
		willpower_bar.value = maxf(NotificationManager.current_willpower_time - elapsed, 0.0)

func _on_score_changed(new_score: int) -> void:
	score_label.text = "%dm" % new_score

func _on_zone_changed(new_zone: GameState.Zone) -> void:
	zone_label.text = ZONE_NAMES[new_zone]

func _on_notification_arrived(_id: String) -> void:
	willpower_bar.max_value = NotificationManager.current_willpower_time
	willpower_bar.value = NotificationManager.current_willpower_time
	willpower_bar.visible = true

func _on_notification_dismissed() -> void:
	willpower_bar.visible = false
