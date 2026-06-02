extends Node

func change_to(scene_path: String) -> void:
	GameState.reset_metrics()
	NotificationManager.stop()
	get_tree().change_scene_to_file(scene_path)
