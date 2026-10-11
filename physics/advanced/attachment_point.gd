class_name AttachmentPoint
extends RefCounted
## World position is always derived from the current body's local attachment.
var reference: WeakRef
var local_position: Vector3
var local_normal: Vector3
var cell: Vector3i
var voxel: bool = false

static func at(body: CollisionObject3D, point: Vector3, normal: Vector3 = Vector3.UP) -> AttachmentPoint:
	var endpoint = AttachmentPoint.new()
	endpoint.reference = weakref(body)
	endpoint.local_position = body.to_local(point)
	endpoint.local_normal = body.global_basis.inverse() * normal
	if body is VoxelBody:
		endpoint.voxel = true
		endpoint.cell = body.world_to_cell(point - normal * body.voxel_size * 0.25)
	return endpoint

func body() -> CollisionObject3D:
	return reference.get_ref() as CollisionObject3D if reference != null else null

func valid() -> bool:
	var object = body()
	return is_instance_valid(object) and not object.is_queued_for_deletion() and (not voxel or (object as VoxelBody).cells.has(cell))

func position() -> Vector3:
	var object = body()
	return object.to_global(local_position) if is_instance_valid(object) else Vector3.ZERO

func normal() -> Vector3:
	return (body().global_basis * local_normal).normalized() if is_instance_valid(body()) else Vector3.UP

func migrate(source: VoxelBody, target: VoxelBody, mapping: Dictionary) -> bool:
	if body() != source or not mapping.has(cell):
		return false
	var world = position()
	var world_normal = normal()
	reference = weakref(target)
	local_position = target.to_local(world)
	local_normal = target.global_basis.inverse() * world_normal
	cell = mapping[cell]
	return true
