extends CharacterBody3D

enum WalkState { WALKING, STOPPED }

const LANE_TWEEN_DURATION: float = 0.2
const ZONE_TRANSITION_TWEEN_DURATION: float = 0.1  # half of lane switch

signal collided_with_hazard
signal stop_pressed
signal check_phone_pressed

var walk_state: WalkState = WalkState.WALKING
var current_lane: int = 0
var _lane_tween: Tween = null

func _physics_process(delta: float) -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var effective_speed: float = GameState.speed if walk_state == WalkState.WALKING else 0.0
	velocity.z = -effective_speed
	if walk_state == WalkState.WALKING:
		GameState.add_distance(effective_speed * delta)

	velocity.y = 0.0
	move_and_slide()

func _input(event: InputEvent) -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		return
	if event.is_action_pressed("stop"):
		stop_pressed.emit()
	elif event.is_action_pressed("check_phone"):
		check_phone_pressed.emit()
		NotificationManager.request_check_phone()
	elif event.is_action_pressed("dismiss_notification"):
		if GameState.phase == GameState.GamePhase.PHONE:
			NotificationManager.dismiss_current()
	elif event.is_action_pressed("lane_left"):
		_try_lane_switch(-1)
	elif event.is_action_pressed("lane_right"):
		_try_lane_switch(1)

func set_walking() -> void:
	walk_state = WalkState.WALKING

func set_stopped() -> void:
	walk_state = WalkState.STOPPED

func _try_lane_switch(delta_lane: int) -> void:
	if GameState.current_zone == null:
		return
	var lane_count: int = GameState.current_zone.lane_count
	if lane_count < 2:
		return
	var target_lane: int = clampi(current_lane + delta_lane, 0, lane_count - 1)
	if target_lane == current_lane:
		return
	current_lane = target_lane
	var target_x: float = _lane_x_for(current_lane, lane_count)
	if _lane_tween:
		_lane_tween.kill()
	_lane_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_lane_tween.tween_property(self, "position:x", target_x, LANE_TWEEN_DURATION)

func _lane_x_for(lane_index: int, lane_count: int) -> float:
	if lane_count == 1:
		return 0.0
	var path_width: float = GameState.current_zone.path_width if GameState.current_zone else 3.6
	var lane_width: float = path_width / float(lane_count)
	return (float(lane_index) - float(lane_count - 1) / 2.0) * lane_width

func reset_lane_for_current_zone(animate: bool = false) -> void:
	if GameState.current_zone == null:
		return
	var lane_count: int = GameState.current_zone.lane_count
	if lane_count == 1:
		current_lane = 0
	else:
		current_lane = randi() % lane_count
	var target_x: float = _lane_x_for(current_lane, lane_count)
	if _lane_tween:
		_lane_tween.kill()
		_lane_tween = null
	if animate:
		_lane_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_lane_tween.tween_property(self, "position:x", target_x, ZONE_TRANSITION_TWEEN_DURATION)
	else:
		position.x = target_x
