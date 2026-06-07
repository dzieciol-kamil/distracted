extends Node

func change_to(scene_path: String) -> void:
	NotificationManager.stop()
	get_tree().change_scene_to_file(scene_path)
