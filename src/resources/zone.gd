class_name Zone
extends Resource

@export var name_id: String = ""
@export var walk_speed: float = 6.0
@export var willpower_max: float = 3.0
@export var spawn_interval_min: float = 25.0
@export var spawn_interval_max: float = 40.0
@export var hazard_pool: Array[HazardEntry] = []
@export var lane_count: int = 1
