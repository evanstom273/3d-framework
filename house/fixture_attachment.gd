class_name HouseFixtureAttachment
extends Node
## A single house fixture's mounting. No joints or cross-body structural solver.
## Bodies and their debris stay under a stationary assembly, outside the pivot.

signal released

@export var body_path: NodePath
@export var pivot_path: NodePath
@export var support_path: NodePath
@export var support_region: AABB
@export var mount_region: AABB
@export_range(0.0, 1.0) var loss_limit: float = 0.35

var body: VoxelBody
var attached: bool = false
var _support: VoxelBody
var _offset: Transform3D
var _pivot: Node3D
var _initial_count: int
var _queued: bool = false


func _ready() -> void:
	_attach.call_deferred()


func _attach() -> void:
	body = get_node_or_null(body_path) as VoxelBody
	if body == null or body.cells.is_empty():
		return
	_pivot = get_node_or_null(pivot_path) as Node3D if not pivot_path.is_empty() else null
	if not support_path.is_empty():
		_support = get_node_or_null(support_path) as VoxelBody
		if _support == null:
			push_error("House fixture has an invalid support: %s" % get_path())
	_initial_count = body.cells.size()
	if _pivot != null:
		_offset = _pivot.global_transform.affine_inverse() * body.global_transform
	if mount_region.has_volume():
		body.anchors.clear()
		for cell in body.cells:
			if mount_region.has_point((Vector3(cell) + Vector3.ONE * 0.5) * body.voxel_size):
				body.anchors[cell] = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	attached = true
	body.geometry_changed.connect(_queue_check)
	if _support != null:
		_support.geometry_changed.connect(_queue_check)
		_support.tree_exiting.connect(release)
	_queue_check()


func sync_pose() -> void:
	if attached and is_instance_valid(body) and body.freeze and is_instance_valid(_pivot):
		body.global_transform = _pivot.global_transform * _offset


func _queue_check() -> void:
	if attached and not _queued:
		_queued = true
		_check.call_deferred()


func _check() -> void:
	_queued = false
	if not attached:
		return
	if not is_instance_valid(body) or body.cells.is_empty() or not body.freeze:
		release()
		return
	if body.cells.size() <= _initial_count * (1.0 - loss_limit):
		release()
		return
	if mount_region.has_volume() and not _occupied(body, mount_region):
		release()
		return
	if not support_path.is_empty():
		if not is_instance_valid(_support) or not _support.freeze or not _occupied(_support, support_region):
			release()


static func _occupied(target: VoxelBody, region: AABB) -> bool:
	var low := Vector3i((region.position / target.voxel_size).floor())
	var high := Vector3i((region.end / target.voxel_size).ceil())
	for x in range(low.x, high.x):
		for y in range(low.y, high.y):
			for z in range(low.z, high.z):
				var cell := Vector3i(x, y, z)
				if target.cells.has(cell) and region.has_point((Vector3(cell) + Vector3.ONE * 0.5) * target.voxel_size):
					return true
	return false


func release() -> void:
	if not attached:
		return
	attached = false
	if is_instance_valid(body):
		body.anchors.clear()
		body.freeze = false
		body.sleeping = false
		# Let dependent panes/doors notice that their mounting is now loose.
		body.geometry_changed.emit()
	released.emit()
