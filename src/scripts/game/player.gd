extends CharacterBody3D

const LANE_POSITIONS: Array[float] = [-1.2, 0.0, 1.2]
const LANE_TWEEN_DURATION: float = 0.25
const GRAVITY: float = 9.8
const SWIPE_THRESHOLD: float = 40.0

var current_lane: int = 1
var _lane_tween: Tween
var _touch_start: Vector2 = Vector2.ZERO
var _touch_active: bool = false

func _physics_process(delta: float) -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		return
	if GameState.phase == GameState.GamePhase.ROAD:
		velocity.z = -GameState.speed
		GameState.add_distance(GameState.speed * delta)
	else:
		velocity.z = 0.0
	velocity.y -= GRAVITY * delta
	move_and_slide()

func _input(event: InputEvent) -> void:
	if GameState.phase != GameState.GamePhase.ROAD:
		return
	if event.is_action_pressed("lane_left"):
		_change_lane(-1)
	elif event.is_action_pressed("lane_right"):
		_change_lane(1)
	_handle_touch(event)

func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_active = true
		else:
			_touch_active = false
	elif event is InputEventScreenDrag and _touch_active:
		var delta: Vector2 = event.position - _touch_start
		if abs(delta.x) > SWIPE_THRESHOLD:
			_change_lane(1 if delta.x > 0 else -1)
			_touch_active = false

func _change_lane(direction: int) -> void:
	var target: int = clamp(current_lane + direction, 0, 2)
	if target == current_lane:
		return
	current_lane = target
	if _lane_tween:
		_lane_tween.kill()
	_lane_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_lane_tween.tween_property(self, "position:x", LANE_POSITIONS[current_lane], LANE_TWEEN_DURATION)
