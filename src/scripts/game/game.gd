extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hazard_container: Node3D = $WorldContainer/HazardContainer

func _ready() -> void:
	GameState.reset()
	GameState.phase_changed.connect(_on_phase_changed)
	NotificationManager.start()
	HazardSpawner.start(player)

func _on_phase_changed(new_phase: GameState.GamePhase) -> void:
	if new_phase == GameState.GamePhase.GAME_OVER:
		await get_tree().create_timer(1.5).timeout
		SceneManager.go_to("game_over")
