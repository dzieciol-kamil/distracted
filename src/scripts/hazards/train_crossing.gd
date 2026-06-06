class_name TrainCrossing
extends Area3D

signal cleared(node: Node3D)

const TRAIN_SPEED: float = 22.0
const WARN_TIME: float = 1.5
const START_OFFSET: float = 10.0  # units off-screen past road edge

@export var path_half_width: float = 3.0

var _active: bool = false
var _warn_timer: float = 0.0
var _direction: float = 1.0
var _emitted_cleared: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	if GameState.current_zone != null:
		path_half_width = GameState.current_zone.path_width / 2.0
	_direction = 1.0 if randf() < 0.5 else -1.0
	position.x = -(path_half_width + START_OFFSET) * _direction
	position.y = 0.0
	var model: Node3D = get_node_or_null("Model") as Node3D
	if model != null and _direction < 0.0:
		model.rotation_degrees.y += 180.0

func _process(delta: float) -> void:
	if not _active:
		_warn_timer += delta
		if _warn_timer >= WARN_TIME:
			_active = true
		return
	position.x += TRAIN_SPEED * _direction * delta
	if _emitted_cleared:
		return
	var exit_x: float = (path_half_width + START_OFFSET) * _direction
	var past_exit: bool = (
		(_direction > 0.0 and position.x > exit_x)
		or (_direction < 0.0 and position.x < exit_x)
	)
	if past_exit:
		_emitted_cleared = true
		cleared.emit(self)
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_signal("collided_with_hazard"):
			body.emit_signal("collided_with_hazard")
