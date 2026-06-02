extends CharacterBody3D

enum WalkState { WALKING, STOPPED }

const GRAVITY: float = 9.8

signal collided_with_hazard
signal stop_pressed
signal check_phone_pressed

var walk_state: WalkState = WalkState.WALKING

func _physics_process(delta: float) -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var effective_speed: float = GameState.speed if walk_state == WalkState.WALKING else 0.0
	velocity.z = -effective_speed
	if walk_state == WalkState.WALKING:
		GameState.add_distance(effective_speed * delta)

	velocity.y -= GRAVITY * delta
	move_and_slide()

func _input(event: InputEvent) -> void:
	if GameState.phase == GameState.GamePhase.GAME_OVER:
		return
	if event.is_action_pressed("stop"):
		stop_pressed.emit()
		if walk_state == WalkState.WALKING:
			set_stopped()
		else:
			set_walking()
	elif event.is_action_pressed("check_phone"):
		check_phone_pressed.emit()
	elif event.is_action_pressed("dismiss_notification"):
		if GameState.phase == GameState.GamePhase.PHONE:
			NotificationManager.dismiss_current()

func set_walking() -> void:
	walk_state = WalkState.WALKING

func set_stopped() -> void:
	walk_state = WalkState.STOPPED
