extends Area3D

signal cleared(node: Node3D)

const LATERAL_SPEED: float = 4.0
const PATH_HALF_WIDTH: float = 1.8

var _direction: float = 1.0
var _emitted_cleared: bool = false

func _ready() -> void:
	collision_layer = 4  # Layer 3 (Hazards)
	collision_mask = 2   # Layer 2 (Player)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position.x += LATERAL_SPEED * _direction * delta
	if not _emitted_cleared and position.x > PATH_HALF_WIDTH:
		_emitted_cleared = true
		cleared.emit(self)
	if position.x > PATH_HALF_WIDTH + 2.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var player := body as Node
		if player.has_signal("collided_with_hazard"):
			player.emit_signal("collided_with_hazard")
