extends Node3D

const CHUNK_LENGTH: float = 20.0
const ACTIVE_CHUNKS: int = 6
const POOL_SIZE: int = 10

@onready var _player: Node3D = get_parent().get_parent().get_node("Player")

var _pool: Array[Node3D] = []
var _active: Array[Node3D] = []
var _next_z: float = 0.0

func _ready() -> void:
	for i in POOL_SIZE:
		var chunk: Node3D = _make_chunk()
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
		if chunk.position.z > player_z + 15.0:
			_recycle(chunk)
			_spawn_chunk()

func _spawn_chunk() -> void:
	if _pool.is_empty():
		return
	var chunk: Node3D = _pool.pop_back()
	chunk.position.z = _next_z
	chunk.visible = true
	_next_z -= CHUNK_LENGTH
	_active.append(chunk)

func _recycle(chunk: Node3D) -> void:
	_active.erase(chunk)
	chunk.visible = false
	_pool.append(chunk)

func _make_chunk() -> Node3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(3.6, 0.1, CHUNK_LENGTH)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0, -0.05, -CHUNK_LENGTH / 2.0)
	var root: Node3D = Node3D.new()
	root.add_child(mesh_instance)
	return root
