extends Node

var _scenes: Dictionary = {
	"main_menu": preload("res://scenes/ui/main_menu.tscn"),
	"game": preload("res://scenes/game/game.tscn"),
	"game_over": preload("res://scenes/ui/game_over.tscn"),
}

func go_to(scene_name: String) -> void:
	assert(scene_name in _scenes, "Unknown scene: " + scene_name)
	get_tree().change_scene_to_packed(_scenes[scene_name])
