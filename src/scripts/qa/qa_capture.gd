extends RefCounted

const HUD_SAMPLE_NAME := "HUDSample"
const PHONE_SAMPLE_NAME := "PhoneSample"

static func capture_presets(viewport: Viewport, camera: Camera3D, presets: Array[Dictionary], artifact_dir: String) -> bool:
	var artifact_path := ProjectSettings.globalize_path(artifact_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(artifact_path)
	if dir_error != OK:
		push_error("QA capture failed to create artifact dir: %s" % artifact_path)
		return false

	var ui_nodes := _discover_ui_nodes(viewport)
	var original_visibility := _remember_visibility(ui_nodes)
	var had_error := false

	for preset in presets:
		_apply_camera_preset(camera, preset)
		_apply_ui_target(ui_nodes, preset.get("ui_target", ""))
		await _wait_for_render_sync()

		var image := viewport.get_texture().get_image()
		if image == null:
			push_error("QA capture failed for preset: %s" % String(preset.get("name", "unnamed")))
			had_error = true
			continue

		var file_path := artifact_path.path_join("%s.png" % String(preset.get("name", "capture")))
		var save_error := image.save_png(file_path)
		if save_error != OK:
			push_error("QA capture failed to save: %s" % file_path)
			had_error = true
		else:
			print("QA capture saved: %s" % file_path)

	_restore_visibility(ui_nodes, original_visibility)
	await _wait_for_render_sync()
	return not had_error

static func _apply_camera_preset(camera: Camera3D, preset: Dictionary) -> void:
	if preset.has("orthographic_size"):
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = preset["orthographic_size"]
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if preset.has("position"):
		camera.position = preset["position"]
	if preset.has("rotation"):
		camera.rotation_degrees = preset["rotation"]

static func _wait_for_render_sync() -> void:
	await Engine.get_main_loop().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	await Engine.get_main_loop().process_frame
	if DisplayServer.get_name() == "headless":
		await Engine.get_main_loop().process_frame

static func _discover_ui_nodes(viewport: Viewport) -> Dictionary:
	var nodes := {
		"hud": null,
		"phone": null,
	}
	var root := viewport.get_tree().current_scene
	if root == null:
		root = viewport
	nodes["hud"] = _find_node_by_name(root, HUD_SAMPLE_NAME)
	nodes["phone"] = _find_node_by_name(root, PHONE_SAMPLE_NAME)
	return nodes

static func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null

static func _remember_visibility(ui_nodes: Dictionary) -> Dictionary:
	var original := {}
	for key in ui_nodes.keys():
		var node := ui_nodes[key] as Node
		if node != null:
			original[key] = _get_visible(node)
	return original

static func _apply_ui_target(ui_nodes: Dictionary, ui_target: Variant) -> void:
	var target := String(ui_target).to_lower()
	var hud := ui_nodes.get("hud") as Node
	var phone := ui_nodes.get("phone") as Node

	match target:
		"hud":
			_set_visible(hud, true)
			_set_visible(phone, false)
		"phone":
			_set_visible(hud, false)
			_set_visible(phone, true)
		_:
			_set_visible(hud, false)
			_set_visible(phone, false)

static func _restore_visibility(ui_nodes: Dictionary, original_visibility: Dictionary) -> void:
	for key in original_visibility.keys():
		_set_visible(ui_nodes.get(key) as Node, original_visibility[key])

static func _get_visible(node: Node) -> bool:
	if node is CanvasItem:
		return (node as CanvasItem).visible
	if node is CanvasLayer:
		return (node as CanvasLayer).visible
	return true

static func _set_visible(node: Node, is_visible: bool) -> void:
	if node == null:
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = is_visible
	elif node is CanvasLayer:
		(node as CanvasLayer).visible = is_visible
