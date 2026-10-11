class_name KitHardware
extends Node3D
## Door and window furniture (handles, letter plates, strap hinges, knockers)
## fixed to a voxel leaf. It follows the voxels it is screwed to: if they break
## away as a separate piece it goes with them, and once they are destroyed it
## drops off as a small loose object.

## Leaf cells this fitting is fixed through.
var support_cells: Array[Vector3i] = []
var _body: VoxelBody
var _check_queued := false


## Builds `builder`'s geometry as a fitting on `leaf`, fixed through the cells
## within `reach` of `anchor` (leaf-local metres), through the leaf's full depth.
static func mount(leaf: VoxelBody, builder: KitBuilder, fitting_name: String, anchor: Vector3, cell: float, depth: int, reach := 0.04) -> KitHardware:
	var hardware := KitHardware.new()
	hardware.name = fitting_name
	builder.commit(hardware, null, "Mesh")
	var centre := Vector3i((anchor / cell).floor())
	var r := maxi(1, ceili(reach / cell))
	for x in range(centre.x - r, centre.x + r + 1):
		for y in range(centre.y - r, centre.y + r + 1):
			for z in depth:
				hardware.support_cells.append(Vector3i(x, y, z))
	leaf.add_child(hardware)
	return hardware


func _ready() -> void:
	if not Engine.is_editor_hint():
		_bind(get_parent() as VoxelBody)


func _bind(body: VoxelBody) -> void:
	if _body != null:
		if _body.geometry_changed.is_connected(_queue_check):
			_body.geometry_changed.disconnect(_queue_check)
		if _body.cells_transferred.is_connected(_on_cells_transferred):
			_body.cells_transferred.disconnect(_on_cells_transferred)
	_body = body
	if _body != null:
		_body.geometry_changed.connect(_queue_check)
		_body.cells_transferred.connect(_on_cells_transferred)


## Part of the leaf broke away: go with it if that's where most of our fixing went.
func _on_cells_transferred(piece: VoxelBody, mapping: Dictionary) -> void:
	var moved: Array[Vector3i] = []
	for cell in support_cells:
		if mapping.has(cell):
			moved.append(mapping[cell])
	if moved.is_empty() or moved.size() * 2 < _surviving_count() + moved.size():
		return
	support_cells = moved
	reparent(piece, true)
	_bind(piece)


func _surviving_count() -> int:
	var count := 0
	for cell in support_cells:
		if _body.cells.has(cell):
			count += 1
	return count


func _queue_check() -> void:
	if not _check_queued:
		_check_queued = true
		_check.call_deferred()


func _check() -> void:
	_check_queued = false
	if not is_instance_valid(_body) or _surviving_count() > 0:
		return
	_fall()


## Nothing left to hold on to: become a loose object that drops away.
func _fall() -> void:
	var mesh := get_node_or_null(^"Mesh") as MeshInstance3D
	var bounds := mesh.get_aabb() if mesh != null and mesh.mesh != null else AABB(Vector3.ZERO, Vector3.ONE * 0.03)
	var loose := RigidBody3D.new()
	loose.name = name
	loose.mass = 0.3
	loose.collision_layer = 16
	loose.collision_mask = 1 | 2 | 16
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size.max(Vector3.ONE * 0.02)
	shape.shape = box
	shape.position = bounds.get_center()
	loose.add_child(shape)
	var scene := get_tree().current_scene if get_tree().current_scene != null else _body.get_parent()
	scene.add_child(loose)
	loose.global_transform = global_transform
	if not _body.freeze:
		loose.linear_velocity = _body.linear_velocity
	loose.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	_bind(null)
	reparent(loose, true)
	transform = Transform3D.IDENTITY
	# Tidy up eventually, like rubble.
	get_tree().create_timer(40.0).timeout.connect(loose.queue_free)
