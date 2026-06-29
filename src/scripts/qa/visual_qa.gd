extends Node3D

const ZONE_SPACING: float = 14.0
const ROAD_TILE_COUNT: int = 4
const PROP_MARGIN: float = 1.5
const HAZARD_GRID_SPACING: float = 6.5
const ARTIFACT_DIR: String = "res://../qa-artifacts/visual-qa"

const HAZARD_PATHS: Array[String] = [
	"res://scenes/hazards/tractor.tscn",
	"res://scenes/hazards/pies.tscn",
	"res://scenes/hazards/krowa.tscn",
	"res://scenes/hazards/samochod.tscn",
	"res://scenes/hazards/ciezarowka.tscn",
	"res://scenes/hazards/kaluza.tscn",
	"res://scenes/hazards/latarnia.tscn",
	"res://scenes/hazards/skrzynka.tscn",
	"res://scenes/hazards/pociag.tscn",
]

@onready var _camera: Camera3D = $Camera3D
@onready var _boards: Node3D = $Boards
@onready var _ui_root: Node = $UIRoot

func _ready() -> void:
	_build_zone_boards()
	_build_hazard_lineup()
	_build_ui_samples()
	if "--qa-capture" in OS.get_cmdline_user_args():
		await _capture_all()

func get_capture_camera() -> Camera3D:
	return _camera

func get_capture_presets() -> Array[Dictionary]:
	return [
		{"name": "zones", "position": Vector3(0, 70, -6), "rotation": Vector3(-90, 0, 0), "orthographic_size": 96.0},
		{"name": "hazards", "position": Vector3(0, 42, -86), "rotation": Vector3(-90, 0, 0), "orthographic_size": 44.0},
		{"name": "ui_hud", "position": Vector3(0, 12, 18), "rotation": Vector3(-45, 0, 0), "ui_target": "hud"},
		{"name": "ui_phone", "position": Vector3(0, 12, 18), "rotation": Vector3(-45, 0, 0), "ui_target": "phone"},
	]

func _build_zone_boards() -> void:
	for i in range(GameState.ZONES.size()):
		var zone: Resource = GameState.ZONES[i]
		var board := Node3D.new()
		board.name = "Zone_%s" % zone.name_id
		board.position = Vector3((float(i) - 1.5) * ZONE_SPACING, 0.0, 0.0)
		_boards.add_child(board)
		_add_road_tiles(board, zone)
		_add_props(board, zone)
		_add_label(board, zone.name_id.to_upper(), Vector3(0.0, 0.05, 4.0))

func _add_road_tiles(parent: Node3D, zone: Resource) -> void:
	if zone.road_tile == null:
		return
	var rotation_y := deg_to_rad(zone.road_tile_rotation_y)
	var tile_size := _get_scene_depth(zone.road_tile, rotation_y)
	for j in range(ROAD_TILE_COUNT):
		var tile := zone.road_tile.instantiate() as Node3D
		if tile == null:
			continue
		tile.position = Vector3(0.0, 0.0, -float(j) * tile_size)
		tile.rotation.y = rotation_y
		parent.add_child(tile)

func _add_props(parent: Node3D, zone: Resource) -> void:
	if zone.prop_pool.is_empty():
		return
	var prop_count: int = mini(3, zone.prop_pool.size())
	var road_edge: float = zone.path_width / 2.0
	for i in range(prop_count):
		var scene: PackedScene = zone.prop_pool[i]
		if scene == null:
			continue
		for side in [-1.0, 1.0]:
			var prop := scene.instantiate() as Node3D
			if prop == null:
				continue
			prop.position = Vector3(side * (road_edge + PROP_MARGIN + float(i)), 0.0, -float(i) * 3.0)
			prop.scale = Vector3.ONE * zone.prop_scale
			parent.add_child(prop)

func _build_hazard_lineup() -> void:
	var root := Node3D.new()
	root.name = "HazardLineup"
	root.position = Vector3(0.0, 0.0, -80.0)
	_boards.add_child(root)
	for i in range(HAZARD_PATHS.size()):
		var scene := load(HAZARD_PATHS[i]) as PackedScene
		if scene == null:
			push_error("Missing QA hazard scene: " + HAZARD_PATHS[i])
			continue
		var hazard := scene.instantiate() as Node3D
		if hazard == null:
			continue
		var column := i % 3
		var row := i / 3
		hazard.position = Vector3((float(column) - 1.0) * HAZARD_GRID_SPACING, 0.0, -float(row) * HAZARD_GRID_SPACING)
		_prepare_static_preview(hazard)
		root.add_child(hazard)
		_add_label(root, HAZARD_PATHS[i].get_file().get_basename(), hazard.position + Vector3(0.0, 0.05, 1.6))

func _build_ui_samples() -> void:
	var hud_scene := load("res://scenes/game/hud.tscn") as PackedScene
	var phone_scene := load("res://scenes/game/phone_overlay.tscn") as PackedScene
	if hud_scene == null or phone_scene == null:
		push_error("Missing QA UI scenes")
		return
	var hud := hud_scene.instantiate()
	var phone := phone_scene.instantiate()
	hud.name = "HUDSample"
	phone.name = "PhoneSample"
	_ui_root.add_child(hud)
	_ui_root.add_child(phone)
	_configure_hud_sample(hud)
	_configure_phone_sample(phone)

func _configure_hud_sample(hud: Node) -> void:
	var distance_label := hud.get_node_or_null("DistanceLabel") as Label
	if distance_label != null:
		distance_label.text = "742 m"
	var notification_area := hud.get_node_or_null("NotificationArea") as Button
	if notification_area != null:
		notification_area.visible = true
	var notification_icon := hud.get_node_or_null("NotificationArea/NotificationIcon") as Label
	if notification_icon != null:
		notification_icon.text = "!"
	var willpower_bar := hud.get_node_or_null("NotificationArea/WillpowerBar") as ProgressBar
	if willpower_bar != null:
		willpower_bar.max_value = 3.0
		willpower_bar.value = 1.4
	var stop_button := hud.get_node_or_null("StopButton") as Button
	if stop_button != null:
		stop_button.text = "STOP"

func _configure_phone_sample(phone: Node) -> void:
	var phone_frame := phone.get_node_or_null("PhoneFrame") as ColorRect
	if phone_frame != null:
		phone_frame.offset_top = 0.0
		phone_frame.offset_bottom = 675.0
	var sender := phone.get_node_or_null("PhoneFrame/NotificationCard/SenderLabel") as Label
	if sender != null:
		sender.text = "QA notification"
	var text := phone.get_node_or_null("PhoneFrame/NotificationCard/TextLabel") as Label
	if text != null:
		text.text = "Controlled phone overlay sample for readability checks."

func _add_label(parent: Node3D, text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.position = position
	parent.add_child(label)

func _get_scene_depth(scene: PackedScene, rotation_y: float) -> float:
	var temp := scene.instantiate() as Node3D
	if temp == null:
		return 2.0
	temp.rotation.y = rotation_y
	add_child(temp)
	var aabb := _collect_aabb(temp)
	remove_child(temp)
	temp.queue_free()
	return maxf(2.0, aabb.size.z)

func _collect_aabb(node: Node3D) -> AABB:
	var result := AABB()
	if node is MeshInstance3D:
		result = node.global_transform * (node as MeshInstance3D).get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_aabb := _collect_aabb(child as Node3D)
			if child_aabb.size != Vector3.ZERO:
				result = child_aabb if result.size == Vector3.ZERO else result.merge(child_aabb)
	return result

func _prepare_static_preview(node: Node) -> void:
	node.set_script(null)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_prepare_static_preview(child)

func _capture_all() -> void:
	var capture := load("res://scripts/qa/qa_capture.gd")
	if capture == null:
		push_error("QA capture script missing")
		get_tree().quit(1)
		return
	var capture_ok: bool = await capture.capture_presets(get_viewport(), _camera, get_capture_presets(), ARTIFACT_DIR)
	get_tree().quit(0 if capture_ok else 1)
