class_name Zone
extends Resource

@export var name_id: String = ""
@export var walk_speed: float = 6.0
@export var willpower_max: float = 3.0
@export var spawn_interval_min: float = 25.0
@export var spawn_interval_max: float = 40.0
@export var hazard_pool: Array[HazardEntry] = []
@export var lane_count: int = 1

@export var path_width: float = 2.0
@export var path_color: Color = Color(0.4, 0.3, 0.2)
@export var stripe_color: Color = Color(0.85, 0.78, 0.55)
@export var stripe_orientation: int = 0

@export var road_tile: PackedScene
@export var prop_pool: Array[PackedScene] = []
@export var prop_density: float = 5.0
