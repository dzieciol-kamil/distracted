extends Node3D

const CHUNK_LENGTH: float = 20.0
const ACTIVE_CHUNKS: int = 6
const POOL_SIZE: int = 10
const RECYCLE_BEHIND_PLAYER: float = 25.0
const PROP_MARGIN: float = 1.0
const PROP_SPREAD: float = 5.0

@onready var _player: Node3D = get_parent().get_parent().get_node("Player")

var _pool: Array[Node3D] = []
var _active: Array[Node3D] = []
var _next_z: float = 0.0
var _tile_size_cache: Dictionary = {}  # key: "instanceId_rotDeg"

func _ready() -> void:
	for i in POOL_SIZE:
		var chunk: Node3D = Node3D.new()
		chunk.visible = false
		add_child(chunk)
		_pool.append(chunk)
	for i in ACTIVE_CHUNKS:
		_spawn_chunk()

func _process(_delta: float) -> void:
	if not _player:
		return
	var player_z: float = _player.global_position.z
	for chunk in _active.duplicate():
		if chunk.position.z > player_z + RECYCLE_BEHIND_PLAYER:
			_recycle(chunk)
			_spawn_chunk()

func _spawn_chunk() -> void:
	if _pool.is_empty():
		return
	var chunk: Node3D = _pool.pop_back()
	for child in chunk.get_children():
		chunk.remove_child(child)
		child.free()
	chunk.position.z = _next_z
	_build_chunk_visuals(chunk, _next_z)
	chunk.visible = true
	_next_z -= CHUNK_LENGTH
	_active.append(chunk)

func _recycle(chunk: Node3D) -> void:
	_active.erase(chunk)
	chunk.visible = false
	_pool.append(chunk)

func _zone_for_chunk_z(chunk_z: float) -> Resource:
	var distance_at_chunk: float = -chunk_z
	var zone_index: int = 0
	for i in range(GameState.ZONE_THRESHOLDS.size() - 1, -1, -1):
		if distance_at_chunk >= GameState.ZONE_THRESHOLDS[i]:
			zone_index = i
			break
	var safe_idx: int = mini(zone_index, GameState.ZONES.size() - 1)
	return GameState.ZONES[safe_idx]

func _get_tile_size(scene: PackedScene, rotation_y: float) -> float:
	var key: String = "%d_%.0f" % [scene.get_instance_id(), rad_to_deg(rotation_y)]
	if _tile_size_cache.has(key):
		return _tile_size_cache[key]
	var temp: Node3D = scene.instantiate() as Node3D
	temp.rotation.y = rotation_y
	temp.visible = false
	add_child(temp)
	var aabb: AABB = _collect_aabb(temp)
	remove_child(temp)
	temp.free()
	var size: float = aabb.size.z if aabb.size.z > 0.01 else 2.0
	_tile_size_cache[key] = size
	return size

func _collect_aabb(node: Node3D) -> AABB:
	var result: AABB = AABB()
	if node is MeshInstance3D:
		var local_aabb: AABB = (node as MeshInstance3D).get_aabb()
		var world_aabb: AABB = node.global_transform * local_aabb
		result = world_aabb
	for child in node.get_children():
		if child is Node3D:
			var child_aabb: AABB = _collect_aabb(child as Node3D)
			if child_aabb.size != Vector3.ZERO:
				if result.size == Vector3.ZERO:
					result = child_aabb
				else:
					result = result.merge(child_aabb)
	return result

func _build_chunk_visuals(chunk: Node3D, chunk_z: float) -> void:
	var zone: Resource = _zone_for_chunk_z(chunk_z)
	if zone == null:
		return
	_build_road(chunk, zone, chunk_z)
	_build_props(chunk, zone)

func _pick_road_tile(zone: Resource, chunk_z: float) -> PackedScene:
	var distance: float = -chunk_z
	if zone.road_tile_2 != null and zone.road_tile_2_from > 0.0 and distance >= zone.road_tile_2_from:
		return zone.road_tile_2
	return zone.road_tile

func _build_road(chunk: Node3D, zone: Resource, chunk_z: float) -> void:
	var tile_scene: PackedScene = _pick_road_tile(zone, chunk_z)
	if tile_scene == null:
		_build_road_fallback(chunk, zone)
		return
	var rotation_y: float = deg_to_rad(zone.road_tile_rotation_y)
	var tile_size: float = _get_tile_size(tile_scene, rotation_y)
	var tile_count: int = max(1, int(ceil(CHUNK_LENGTH / tile_size)))
	for i in tile_count:
		var tile: Node3D = tile_scene.instantiate() as Node3D
		tile.position = Vector3(0.0, 0.01, -(i * tile_size + tile_size * 0.5))
		tile.rotation.y = rotation_y
		chunk.add_child(tile)

func _build_road_fallback(chunk: Node3D, zone: Resource) -> void:
	var path_mesh: MeshInstance3D = MeshInstance3D.new()
	var path_box: BoxMesh = BoxMesh.new()
	path_box.size = Vector3(zone.path_width, 0.1, CHUNK_LENGTH)
	path_mesh.mesh = path_box
	path_mesh.position = Vector3(0, -0.05, -CHUNK_LENGTH / 2.0)
	var path_material: StandardMaterial3D = StandardMaterial3D.new()
	path_material.albedo_color = zone.path_color
	path_mesh.material_override = path_material
	chunk.add_child(path_mesh)

func _build_props(chunk: Node3D, zone: Resource) -> void:
	if zone.prop_pool.is_empty() or zone.prop_density <= 0.0:
		return
	var road_edge: float = zone.path_width / 2.0
	var z: float = -zone.prop_density * 0.5
	while z > -CHUNK_LENGTH:
		var prop_scene: PackedScene = zone.prop_pool[randi() % zone.prop_pool.size()]
		if prop_scene != null:
			_place_prop(chunk, prop_scene, road_edge, z, -1.0, zone.prop_scale)
			_place_prop(chunk, prop_scene, road_edge, z, 1.0, zone.prop_scale)
		z -= zone.prop_density

func _place_prop(chunk: Node3D, scene: PackedScene, road_edge: float, z: float, side: float, scale: float) -> void:
	var prop: Node3D = scene.instantiate() as Node3D
	var x_offset: float = road_edge + PROP_MARGIN + randf() * PROP_SPREAD
	prop.position = Vector3(side * x_offset, 0.0, z)
	prop.rotation.y = float(randi() % 4) * PI * 0.5
	prop.scale = Vector3.ONE * scale
	chunk.add_child(prop)
