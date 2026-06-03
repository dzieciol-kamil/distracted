class_name LaneObstacle
extends Area3D

signal cleared(node: Node3D)

@export var clear_distance_behind_player: float = 2.0

var _emitted_cleared: bool = false
var _player: Node3D = null

func _ready() -> void:
	collision_layer = 4  # Layer 3 (Hazards)
	collision_mask = 2   # Layer 2 (Player)
	body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	if _emitted_cleared:
		return
	if _player.global_position.z + clear_distance_behind_player < global_position.z:
		_emitted_cleared = true
		cleared.emit(self)
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_signal("collided_with_hazard"):
			body.emit_signal("collided_with_hazard")
