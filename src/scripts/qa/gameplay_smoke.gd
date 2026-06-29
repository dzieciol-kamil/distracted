extends Node

const ARTIFACT_DIR := "res://../qa-artifacts/gameplay-smoke"
const QA_ARGS := "--qa-gameplay-smoke"
const PHONE_NOTIFICATION_PATH := "res://resources/notifications/mama_zjadles.tres"
const PHONE_OPEN_TIMEOUT_SECONDS := 2.0

@onready var _camera: Camera3D = $"../GameCamera"
@onready var _player = $"../Player"
@onready var _phone_overlay: CanvasLayer = $"../PhoneOverlay"

var _hazard_spawned: bool = false

func _ready() -> void:
	if QA_ARGS not in OS.get_cmdline_user_args():
		return
	seed(22)
	call_deferred("_run_smoke")

func _run_smoke() -> void:
	print("QA gameplay smoke: start")
	HazardSpawner.hazard_spawned.connect(_on_hazard_spawned)

	await _wait_for_scene_ready()
	GameState.current_zone = GameState.ZONES[GameState.ZoneIndex.SUBURB]
	GameState.zone = GameState.ZoneIndex.SUBURB
	GameState.speed = GameState.current_zone.walk_speed
	GameState.distance = 490.0
	print("QA gameplay smoke: capture 01_game_loaded")
	if not await _capture_named("01_game_loaded"):
		return

	_player.set_walking()
	await get_tree().create_timer(1.2).timeout
	print("QA gameplay smoke: capture 02_after_short_walk")
	if not await _capture_named("02_after_short_walk"):
		return

	if not await _open_phone_overlay_for_capture():
		return
	print("QA gameplay smoke: capture 03_phone_overlay")
	if not await _capture_named("03_phone_overlay"):
		return

	if not _hazard_spawned:
		push_warning("QA gameplay smoke: no hazard spawned during smoke window")

	print("QA gameplay smoke: complete")
	get_tree().quit()

func _wait_for_scene_ready() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	await get_tree().process_frame

func _capture_named(name: String) -> bool:
	var capture := load("res://scripts/qa/qa_capture.gd")
	if capture == null:
		push_error("QA gameplay smoke: capture script missing")
		get_tree().quit(1)
		return false
	var preset: Dictionary = {
		"name": name,
		"position": _camera.position,
		"rotation": _camera.rotation_degrees,
	}
	if name == "03_phone_overlay":
		preset["ui_target"] = "phone"
	var presets: Array[Dictionary] = [preset]
	var capture_ok: bool = await capture.capture_presets(get_viewport(), _camera, presets, ARTIFACT_DIR)
	if not capture_ok:
		get_tree().quit(1)
	return capture_ok

func _open_phone_overlay_for_capture() -> bool:
	var notification := load(PHONE_NOTIFICATION_PATH)
	if notification == null:
		push_error("QA gameplay smoke: missing notification resource")
		get_tree().quit(1)
		return false

	NotificationManager.current_notification = notification
	NotificationManager.willpower_remaining = NotificationManager._current_willpower_max()
	NotificationManager.willpower_active = true
	NotificationManager.notification_arrived.emit(notification)
	NotificationManager.request_check_phone()

	var phone_frame := _phone_overlay.get_node_or_null("PhoneFrame")
	if phone_frame == null:
		push_error("QA gameplay smoke: missing phone frame")
		get_tree().quit(1)
		return false

	var deadline := Time.get_ticks_msec() + int(PHONE_OPEN_TIMEOUT_SECONDS * 1000.0)
	while phone_frame.offset_top < 0.0:
		if Time.get_ticks_msec() >= deadline:
			push_error("QA gameplay smoke: phone overlay did not open before timeout")
			get_tree().quit(1)
			return false
		await get_tree().process_frame
	return true

func _on_hazard_spawned(_node: Node3D) -> void:
	_hazard_spawned = true
