# Godot 4 Code Patterns — Distracted

Reference for common implementation patterns. Load when you need concrete examples.

---

## Signals

```gdscript
signal lane_changed(new_lane: int)
signal notification_triggered(notification_id: String)
signal phase_changed(new_phase: GameState.GamePhase)

# Emission
lane_changed.emit(current_lane)

# Connection
some_node.phase_changed.connect(_on_phase_changed)

# Disconnect on exit
func _exit_tree() -> void:
    some_node.phase_changed.disconnect(_on_phase_changed)
```

---

## GameState autoload

```gdscript
# game_state.gd
extends Node

enum GamePhase { ROAD, PHONE, GAME_OVER, PAUSED }
enum Zone { VILLAGE, SUBURB, TOWN, CITY }

signal phase_changed(new_phase: GamePhase)
signal zone_changed(new_zone: Zone)

var phase: GamePhase = GamePhase.ROAD
var zone: Zone = Zone.VILLAGE
var distance: float = 0.0
var score: int = 0
var speed: float = 6.0

func set_phase(new_phase: GamePhase) -> void:
    if phase == new_phase:
        return
    phase = new_phase
    phase_changed.emit(phase)

func update_zone() -> void:
    var new_zone: Zone
    if distance < 500.0:
        new_zone = Zone.VILLAGE
    elif distance < 1500.0:
        new_zone = Zone.SUBURB
    elif distance < 3000.0:
        new_zone = Zone.TOWN
    else:
        new_zone = Zone.CITY
    if new_zone != zone:
        zone = new_zone
        zone_changed.emit(zone)
```

---

## Player (CharacterBody3D, lane movement)

```gdscript
# player.gd
extends CharacterBody3D

const LANE_POSITIONS: Array[float] = [-1.2, 0.0, 1.2]
const LANE_TWEEN_DURATION: float = 0.25

var current_lane: int = 1  # 0=left, 1=center, 2=right
var _lane_tween: Tween

func _physics_process(delta: float) -> void:
    if GameState.phase != GameState.GamePhase.ROAD:
        return
    velocity.z = -GameState.speed
    velocity.y -= 9.8 * delta  # gravity
    move_and_slide()
    GameState.distance += GameState.speed * delta

func change_lane(direction: int) -> void:
    # direction: -1 = left, +1 = right
    var target_lane: int = clamp(current_lane + direction, 0, 2)
    if target_lane == current_lane:
        return
    current_lane = target_lane
    if _lane_tween:
        _lane_tween.kill()
    _lane_tween = create_tween().set_ease(Tween.EASE_IN_OUT)
    _lane_tween.tween_property(self, "position:x", LANE_POSITIONS[current_lane], LANE_TWEEN_DURATION)
```

---

## Swipe input detection

```gdscript
# touch_input.gd (autoload or child node of Player)
extends Node

const SWIPE_THRESHOLD: float = 40.0

var _touch_start: Vector2 = Vector2.ZERO
var _touch_active: bool = false

signal swiped_left
signal swiped_right
signal tapped

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_start = event.position
            _touch_active = true
        else:
            if _touch_active:
                var delta: Vector2 = event.position - _touch_start
                if delta.length() < 10.0:
                    tapped.emit()
            _touch_active = false
    elif event is InputEventScreenDrag and _touch_active:
        var delta: Vector2 = event.position - _touch_start
        if abs(delta.x) > SWIPE_THRESHOLD:
            if delta.x < 0:
                swiped_left.emit()
            else:
                swiped_right.emit()
            _touch_active = false
```

---

## Road chunk pool

```gdscript
# chunk_manager.gd
extends Node3D

const CHUNK_LENGTH: float = 20.0
const ACTIVE_CHUNKS: int = 6
const POOL_SIZE: int = 10

var _chunk_scene: PackedScene = preload("res://scenes/game/road_chunk.tscn")
var _pool: Array[Node3D] = []
var _active: Array[Node3D] = []
var _next_z: float = 0.0

func _ready() -> void:
    for i in POOL_SIZE:
        var chunk: Node3D = _chunk_scene.instantiate()
        chunk.visible = false
        add_child(chunk)
        _pool.append(chunk)
    for i in ACTIVE_CHUNKS:
        _spawn_chunk()

func _process(_delta: float) -> void:
    var player_z: float = get_parent().get_node("Player").position.z
    # Recycle chunks that are behind the player
    for chunk in _active.duplicate():
        if chunk.position.z > player_z + 15.0:
            _recycle(chunk)
            _spawn_chunk()

func _spawn_chunk() -> void:
    if _pool.is_empty():
        return
    var chunk: Node3D = _pool.pop_back()
    chunk.position.z = _next_z
    chunk.visible = true
    _next_z -= CHUNK_LENGTH
    _active.append(chunk)

func _recycle(chunk: Node3D) -> void:
    _active.erase(chunk)
    chunk.visible = false
    _pool.append(chunk)
```

---

## Phone overlay (CanvasLayer slide-in)

```gdscript
# phone_overlay.gd
extends CanvasLayer

const SLIDE_DURATION: float = 0.4
const HIDDEN_Y: float = -900.0  # above screen

@onready var phone_panel: Panel = $PhonePanel
@onready var notification_label: Label = $PhonePanel/NotificationLabel

func _ready() -> void:
    phone_panel.position.y = HIDDEN_Y
    GameState.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
    if new_phase == GameState.GamePhase.PHONE:
        _slide_in()
    elif phone_panel.position.y > HIDDEN_Y:
        _slide_out()

func _slide_in() -> void:
    var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(phone_panel, "position:y", 0.0, SLIDE_DURATION)

func _slide_out() -> void:
    var tween: Tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    tween.tween_property(phone_panel, "position:y", HIDDEN_Y, SLIDE_DURATION)
    await tween.finished

func show_notification(notification_id: String, text: String) -> void:
    notification_label.text = text
```

---

## Willpower bar (Timer-driven)

```gdscript
# willpower_bar.gd
extends Control

@onready var bar: ProgressBar = $ProgressBar
@onready var countdown_timer: Timer = $CountdownTimer

var max_time: float = 5.0

func _ready() -> void:
    countdown_timer.timeout.connect(_on_timeout)
    NotificationManager.notification_arrived.connect(_on_notification_arrived)

func _on_notification_arrived(_id: String) -> void:
    if GameState.phase != GameState.GamePhase.ROAD:
        return
    max_time = NotificationManager.current_willpower_time
    bar.max_value = max_time
    bar.value = max_time
    countdown_timer.wait_time = 0.05  # update every 50ms
    countdown_timer.start()

func _on_timeout() -> void:
    bar.value -= 0.05
    if bar.value <= 0.0:
        countdown_timer.stop()
        GameState.set_phase(GameState.GamePhase.PHONE)
```

---

## Hazard base class

```gdscript
# base_hazard.gd
class_name BaseHazard
extends Node3D

signal hit_player

@onready var detection_area: Area3D = $DetectionArea

func _ready() -> void:
    detection_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        hit_player.emit()
        GameState.set_phase(GameState.GamePhase.GAME_OVER)

func configure(lane: int, speed_override: float = 0.0) -> void:
    position.x = [-1.2, 0.0, 1.2][lane]
    # subclasses override for moving hazards
```

---

## Camera follow (3D, behind player)

```gdscript
# game_camera.gd
extends Camera3D

const OFFSET: Vector3 = Vector3(0, 4, 8)
const FOLLOW_SPEED: float = 10.0

var _target: Node3D

func _ready() -> void:
    _target = get_parent().get_node("Player")

func _process(delta: float) -> void:
    var desired: Vector3 = _target.global_position + OFFSET
    global_position = global_position.lerp(desired, FOLLOW_SPEED * delta)
    look_at(_target.global_position, Vector3.UP)
```

---

## Notification JSON format

```json
[
  {
    "id": "mom_photos",
    "app": "SMS",
    "sender": "Mama",
    "text": "Wysłałam ci 47 zdjęć, widziałeś?",
    "action": "dismiss"
  },
  {
    "id": "car_warranty",
    "app": "Połączenie",
    "sender": "+48 800 100 200",
    "text": "Twoja gwarancja samochodu wygasła",
    "action": "decline"
  }
]
```

---

## SceneManager autoload

```gdscript
# scene_manager.gd
extends Node

var _scenes: Dictionary = {
    "main_menu": preload("res://scenes/ui/main_menu.tscn"),
    "game": preload("res://scenes/game/game.tscn"),
    "game_over": preload("res://scenes/ui/game_over.tscn"),
}

func go_to(scene_name: String) -> void:
    assert(scene_name in _scenes, "Unknown scene: " + scene_name)
    get_tree().change_scene_to_packed(_scenes[scene_name])
```

---

## Headless validation

```bash
# Run after every non-trivial change:
godot --path /Users/kamil/Projects/distracted/src/ --headless --quit 2>&1
# Exit code 0 + no "ERROR:" lines = ok
```

---

## Mobile touch input (keyboard fallback)

In `project.godot` InputMap, define actions with both keyboard and touch equivalents:
- `lane_left` — keyboard: A / Left; touch: swipe left signal
- `lane_right` — keyboard: D / Right; touch: swipe right signal
- `dismiss_notification` — keyboard: Escape; touch: swipe up on phone

Never hardcode `KEY_*` or `MOUSE_BUTTON_*` in gameplay scripts.
