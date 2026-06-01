extends Camera3D

const OFFSET: Vector3 = Vector3(0, 4, 8)
const FOLLOW_SPEED: float = 10.0

var _target: Node3D

func _ready() -> void:
	_target = get_parent().get_node("Player")

func _process(delta: float) -> void:
	if not _target:
		return
	var desired: Vector3 = _target.global_position + OFFSET
	global_position = global_position.lerp(desired, FOLLOW_SPEED * delta)
	look_at(_target.global_position, Vector3.UP)
