extends Node3D

func _ready() -> void:
	if get_parent().position.x > 0.0:
		rotation_degrees.y += 180.0
