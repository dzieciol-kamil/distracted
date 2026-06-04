extends Node3D

const CHUNK_LENGTH: float = 20.0
const ACTIVE_CHUNKS: int = 6
const POOL_SIZE: int = 10
const RECYCLE_BEHIND_PLAYER: float = 25.0
const STRIPE_INTERVAL: float = 4.0
const STRIPE_LENGTH_TRANSVERSE: float = 0.3
const STRIPE_LENGTH_LONGITUDINAL: float = 2.5
const LONGITUDINAL_GAP: float = 1.5

@onready var _player: Node3D = get_parent().get_parent().get_node("Player")

var _pool: Array[Node3D] = []
var _active: Array[Node3D] = []
var _next_z: float = 0.0

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
		child.queue_free()
	_build_chunk_visuals(chunk)
	chunk.position.z = _next_z
	chunk.visible = true
	_next_z -= CHUNK_LENGTH
	_active.append(chunk)

func _recycle(chunk: Node3D) -> void:
	_active.erase(chunk)
	chunk.visible = false
	_pool.append(chunk)

func _build_chunk_visuals(chunk: Node3D) -> void:
	var zone: Resource = GameState.current_zone
	var path_width: float = zone.path_width if zone != null else 3.6
	var path_color: Color = zone.path_color if zone != null else Color(0.4, 0.3, 0.2)
	var stripe_color: Color = zone.stripe_color if zone != null else Color(0.85, 0.78, 0.55)
	var stripe_orientation: int = zone.stripe_orientation if zone != null else 0

	var path_mesh: MeshInstance3D = MeshInstance3D.new()
	var path_box: BoxMesh = BoxMesh.new()
	path_box.size = Vector3(path_width, 0.1, CHUNK_LENGTH)
	path_mesh.mesh = path_box
	path_mesh.position = Vector3(0, -0.05, -CHUNK_LENGTH / 2.0)
	var path_material: StandardMaterial3D = StandardMaterial3D.new()
	path_material.albedo_color = path_color
	path_mesh.material_override = path_material
	chunk.add_child(path_mesh)

	var stripe_material: StandardMaterial3D = StandardMaterial3D.new()
	stripe_material.albedo_color = stripe_color

	if stripe_orientation == 0:
		var stripe_box: BoxMesh = BoxMesh.new()
		stripe_box.size = Vector3(path_width - 0.2, 0.04, STRIPE_LENGTH_TRANSVERSE)
		var z: float = -STRIPE_INTERVAL
		while z > -CHUNK_LENGTH:
			var stripe: MeshInstance3D = MeshInstance3D.new()
			stripe.mesh = stripe_box
			stripe.material_override = stripe_material
			stripe.position = Vector3(0, 0.01, z)
			chunk.add_child(stripe)
			z -= STRIPE_INTERVAL
	else:
		var stripe_box: BoxMesh = BoxMesh.new()
		stripe_box.size = Vector3(0.15, 0.04, STRIPE_LENGTH_LONGITUDINAL)
		var z: float = -1.0
		while z > -CHUNK_LENGTH + 0.5:
			var stripe: MeshInstance3D = MeshInstance3D.new()
			stripe.mesh = stripe_box
			stripe.material_override = stripe_material
			stripe.position = Vector3(0, 0.01, z)
			chunk.add_child(stripe)
			z -= STRIPE_LENGTH_LONGITUDINAL + LONGITUDINAL_GAP
