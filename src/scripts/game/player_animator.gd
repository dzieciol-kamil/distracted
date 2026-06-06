extends Node3D

const _CHAR_SCENE := preload("res://art/kenney_animated-characters-protagonists/Model/characterMedium.fbx")
const _IDLE_SCENE := preload("res://art/kenney_animated-characters-protagonists/Animations/idle.fbx")
const _RUN_SCENE := preload("res://art/kenney_animated-characters-protagonists/Animations/run.fbx")
const _SKIN_TEXTURE := preload("res://art/kenney_animated-characters-protagonists/Skins/skaterMaleA.png")

const _ANIM_IDLE: StringName = &"idle/Root|Idle"
const _ANIM_RUN: StringName = &"run/Root|Run"

var _anim_player: AnimationPlayer
var _current_anim: StringName = &""

func _ready() -> void:
	var character: Node3D = _CHAR_SCENE.instantiate()
	character.name = "characterMedium"
	add_child(character)
	_apply_skin(character)

	_anim_player = AnimationPlayer.new()
	add_child(_anim_player)

	_load_anim_library(_IDLE_SCENE, &"idle")
	_load_anim_library(_RUN_SCENE, &"run")

	GameState.phase_changed.connect(_on_phase_changed)
	_update_animation()

func _process(_delta: float) -> void:
	_update_animation()

func _apply_skin(character: Node3D) -> void:
	var mesh: MeshInstance3D = character.find_child("characterMedium", true, false) as MeshInstance3D
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _SKIN_TEXTURE
	mesh.material_override = mat

func _load_anim_library(scene: PackedScene, lib_name: StringName) -> void:
	var temp: Node = scene.instantiate()
	var src_ap: AnimationPlayer = temp.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src_ap == null:
		temp.queue_free()
		return

	var lib := AnimationLibrary.new()
	for src_lib_name: StringName in src_ap.get_animation_library_list():
		var src_lib: AnimationLibrary = src_ap.get_animation_library(src_lib_name)
		for anim_name: StringName in src_lib.get_animation_list():
			var anim: Animation = src_lib.get_animation(anim_name).duplicate()
			for i: int in anim.get_track_count():
				var remapped: String = "characterMedium/" + str(anim.track_get_path(i))
				anim.track_set_path(i, NodePath(remapped))
			lib.add_animation(anim_name, anim)
	_anim_player.add_animation_library(lib_name, lib)
	temp.queue_free()

func _on_phase_changed(_new_phase: GameState.GamePhase) -> void:
	_update_animation()

func _update_animation() -> void:
	if _anim_player == null:
		return
	var player_node: Node = get_parent()
	var walk_state: int = player_node.get("walk_state") if player_node else 0
	# WalkState.WALKING == 0
	var is_walking: bool = (
		GameState.phase != GameState.GamePhase.PHONE
		and GameState.phase != GameState.GamePhase.GAME_OVER
		and walk_state == 0
	)

	var target: StringName = _ANIM_RUN if is_walking else _ANIM_IDLE
	if target == _current_anim:
		return
	if _anim_player.has_animation(target):
		_anim_player.play(target)
		_current_anim = target
