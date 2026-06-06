class_name TrainCrossing
extends Area3D

signal cleared(node: Node3D)

const TRAIN_SPEED: float = 22.0
const WARN_TIME: float = 1.5
const START_OFFSET: float = 10.0
const CARRIAGE_SPACING: float = 6.0
const TRAIN_REAR_OFFSET: float = 18.0  # 3 carriages * CARRIAGE_SPACING

const CARRIAGE_COLORS: Array[Color] = [
	Color(0.85, 0.15, 0.15),
	Color(0.15, 0.35, 0.85),
	Color(0.15, 0.65, 0.25),
	Color(0.85, 0.65, 0.10),
	Color(0.55, 0.10, 0.65),
]

@export var path_half_width: float = 3.0

@onready var _loco: Node3D = $Model
@onready var _carriage1: Node3D = $Carriage1
@onready var _carriage2: Node3D = $Carriage2
@onready var _carriage3: Node3D = $Carriage3
@onready var _col: CollisionShape3D = $CollisionShape3D

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

	if _direction < 0.0:
		_loco.rotation_degrees.y += 180.0

	# Carriages trail behind locomotive in direction of travel
	_carriage1.position.x = -CARRIAGE_SPACING * 1.0 * _direction
	_carriage2.position.x = -CARRIAGE_SPACING * 2.0 * _direction
	_carriage3.position.x = -CARRIAGE_SPACING * 3.0 * _direction

	# Center collision box on entire train (loco at 0, last carriage at -TRAIN_REAR_OFFSET*dir)
	_col.position.x = -(TRAIN_REAR_OFFSET / 2.0) * _direction

	_tint_carriages()

func _process(delta: float) -> void:
	if not _active:
		_warn_timer += delta
		if _warn_timer >= WARN_TIME:
			_active = true
		return
	position.x += TRAIN_SPEED * _direction * delta
	if _emitted_cleared:
		return
	# Wait until the last carriage has fully cleared the road
	var past_exit: bool = (
		(_direction > 0.0 and position.x > path_half_width + TRAIN_REAR_OFFSET)
		or (_direction < 0.0 and position.x < -(path_half_width + TRAIN_REAR_OFFSET))
	)
	if past_exit:
		_emitted_cleared = true
		cleared.emit(self)
		queue_free()

func _tint_carriages() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = CARRIAGE_COLORS[randi() % CARRIAGE_COLORS.size()]
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	for carriage in [_carriage1, _carriage2, _carriage3]:
		for mesh in (carriage as Node3D).find_children("*", "MeshInstance3D"):
			(mesh as MeshInstance3D).material_overlay = mat

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_signal("collided_with_hazard"):
			body.emit_signal("collided_with_hazard")
