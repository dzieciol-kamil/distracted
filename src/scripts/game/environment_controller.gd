extends Node

const ZONE_COLORS: Array[Color] = [
	Color("#4caf50"),  # VILLAGE — green grass
	Color("#388e3c"),  # SUBURB  — darker green
	Color("#78909c"),  # TOWN    — grey-green
	Color("#546e7a"),  # CITY    — concrete grey
]
const TWEEN_DURATION: float = 0.5

var _tween: Tween

@onready var _ground_plane: MeshInstance3D = $"../GroundPlane"
@onready var _ground_material: StandardMaterial3D = (
	$"../GroundPlane" as MeshInstance3D
).get_surface_override_material(0)
@onready var _player: Node3D = $"../Player"

func _ready() -> void:
	_ground_material.albedo_color = ZONE_COLORS[GameState.zone]
	GameState.zone_changed.connect(_on_zone_changed)

func _process(_delta: float) -> void:
	if _player:
		_ground_plane.position.z = _player.global_position.z

func _on_zone_changed(new_zone: GameState.ZoneIndex) -> void:
	if _tween:
		_tween.kill()
	var target: Color = ZONE_COLORS[mini(new_zone, ZONE_COLORS.size() - 1)]
	_tween = create_tween()
	_tween.tween_property(_ground_material, "albedo_color", target, TWEEN_DURATION)
