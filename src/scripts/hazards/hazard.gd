class_name Hazard
extends Area3D

signal cleared(node: Node3D)

@export var lateral_speed: float = 1.5
@export var path_half_width: float = 1.8

var _direction: float = 1.0
var _emitted_cleared: bool = false
var _player: Node3D = null

func _ready() -> void:
	collision_layer = 4  # Layer 3 (Hazards)
	collision_mask = 2   # Layer 2 (Player)
	body_entered.connect(_on_body_entered)
	if GameState.current_zone != null:
		path_half_width = GameState.current_zone.path_width / 2.0
	_direction = -signf(position.x)
	if _direction == 0.0:
		_direction = 1.0
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_orient_model()

func _process(delta: float) -> void:
	position.x += lateral_speed * _direction * delta
	if not _emitted_cleared:
		var past_far_edge: bool = (
			(_direction > 0.0 and position.x > path_half_width)
			or (_direction < 0.0 and position.x < -path_half_width)
		)
		if past_far_edge:
			_emitted_cleared = true
			cleared.emit(self)
	if absf(position.x) > path_half_width + 10.0:
		var behind_player: bool = _player == null or global_position.z > _player.global_position.z + 2.0
		if behind_player:
			queue_free()

func _orient_model() -> void:
	var model: Node3D = get_node_or_null("Model") as Node3D
	if model == null:
		return
	if _direction < 0.0:
		model.rotation_degrees.y += 180.0

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_signal("collided_with_hazard"):
			body.emit_signal("collided_with_hazard")
