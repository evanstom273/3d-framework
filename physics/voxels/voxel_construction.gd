class_name VoxelConstruction
extends RefCounted
## Building with voxels: where a trowel would place the next voxel, placing it,
## and cementing a held broken piece back into a fixed structure.

## Layers a placement ray can land on: world, platforms, interactables and props.
const PLACE_MASK := 1 | 2 | 4 | 16
## Layers a new voxel must not overlap: the player and loose props.
const BLOCK_MASK := 8 | 16


## Where a voxel would go for a ray from `origin` along `direction`. Returns {} if
## nothing in reach, otherwise {body (VoxelBody or null for a new structure),
## cell, world_cell, size, anchored, valid, transform (the voxel's box, for previews)}.
static func find_place_target(world: World3D, origin: Vector3, direction: Vector3, reach: float,
		exclude: Array[RID], new_size: float) -> Dictionary:
	var space := world.direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * reach, PLACE_MASK, exclude)
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return {}
	var collider: Object = hit["collider"]
	var normal: Vector3 = hit["normal"]
	var target := {}
	var body := collider as VoxelBody
	if body != null:
		var cell := body.world_to_cell(hit["position"] + normal * body.voxel_size * 0.5)
		target = {"body": body, "cell": cell, "size": body.voxel_size,
			"transform": Transform3D(body.global_basis.orthonormalized(), body.cell_to_world(cell))}
	else:
		# Only build on fixed surfaces; a voxel stuck to a loose prop would fight its physics.
		if collider is RigidBody3D or collider is CharacterBody3D:
			return {}
		var point: Vector3 = hit["position"] + normal * new_size * 0.5
		var adjacent := _adjacent_structure(world, point, new_size)
		if adjacent != null:
			var cell := adjacent.world_to_cell(point)
			target = {"body": adjacent, "cell": cell, "size": adjacent.voxel_size,
				"transform": Transform3D(adjacent.global_basis.orthonormalized(), adjacent.cell_to_world(cell))}
		else:
			var world_cell := Vector3i((point / new_size).floor())
			target = {"body": null, "world_cell": world_cell, "size": new_size,
				"transform": Transform3D(Basis(), (Vector3(world_cell) + Vector3.ONE * 0.5) * new_size)}
	var centre: Vector3 = target["transform"].origin
	target["anchored"] = _rests_on_world(space, centre, target["size"], target.get("body"))
	target["valid"] = not _blocked(space, target["transform"], target["size"], target.get("body"))
	return target


## Places the voxel described by a target from find_place_target().
static func place(target: Dictionary, material: VoxelMaterialDefinition, parent: Node) -> VoxelBody:
	if target.is_empty() or not target["valid"] or material == null:
		return null
	var body: VoxelBody = target.get("body")
	if body != null:
		body.add_voxel(target["cell"], material, target["anchored"])
		return body
	return VoxelBody.create_built(parent, target["world_cell"], target["size"], material, target["anchored"])


## The fixed structure a held piece would cement into, or null.
static func find_cement_target(piece: VoxelBody) -> VoxelBody:
	var best: VoxelBody = null
	var best_count := 0
	for node in piece.get_tree().get_nodes_in_group(&"voxel_bodies"):
		var structure := node as VoxelBody
		if structure == null or structure == piece or not structure.freeze or structure.cells.is_empty():
			continue
		if not is_equal_approx(structure.voxel_size, piece.voxel_size):
			continue
		if structure.global_position.distance_to(piece.global_position) > 30.0:
			continue
		var count := _plan_cement(piece, structure).size()
		if count > best_count:
			best = structure
			best_count = count
	return best


## Moves as many of the piece's voxels as fit into the structure. Voxels that
## can't go in stay in the piece, so nothing is created or lost. Returns how many moved.
static func cement(piece: VoxelBody, structure: VoxelBody) -> int:
	var plan := _plan_cement(piece, structure)
	var space := structure.get_world_3d().direct_space_state
	for piece_cell: Vector3i in plan:
		var target_cell: Vector3i = plan[piece_cell]
		var moved := piece.take_voxel(piece_cell)
		if moved.is_empty():
			continue
		var anchored := _rests_on_world(space, structure.cell_to_world(target_cell), structure.voxel_size, structure)
		structure.add_voxel(target_cell, moved[0], anchored, moved[1])
	return plan.size()


## Maps piece cells to structure cells: the piece's rotation snaps to the nearest
## 90 degree alignment, and only empty cells joined to the structure are used.
static func _plan_cement(piece: VoxelBody, structure: VoxelBody) -> Dictionary:
	var relative := structure.global_basis.orthonormalized().inverse() * piece.global_basis.orthonormalized()
	var snapped := Basis(_snap_axis(relative.x), _snap_axis(relative.y), _snap_axis(relative.z))
	if absf(snapped.determinant() - 1.0) > 0.01:
		return {}
	var origin := structure.to_local(piece.global_position) / structure.voxel_size
	var mapped := {}
	var taken := {}
	for cell: Vector3i in piece.cells:
		var target := Vector3i((origin + snapped * (Vector3(cell) + Vector3.ONE * 0.5) - Vector3.ONE * 0.5).round())
		if structure.cells.has(target) or taken.has(target):
			continue
		mapped[cell] = target
		taken[target] = cell
	# Keep only cells connected (through each other) to the existing structure.
	var queue: Array = []
	var accepted := {}
	for target in taken:
		for offset in VoxelBody.NEIGHBOURS:
			if structure.cells.has(target + offset):
				queue.append(target)
				accepted[target] = true
				break
	if queue.is_empty():
		return {}
	var next := 0
	while next < queue.size():
		var target: Vector3i = queue[next]
		next += 1
		for offset in VoxelBody.NEIGHBOURS:
			var neighbour := target + offset
			if taken.has(neighbour) and not accepted.has(neighbour):
				accepted[neighbour] = true
				queue.append(neighbour)
	var plan := {}
	for target in accepted:
		plan[taken[target]] = target
	return plan


static func _snap_axis(axis: Vector3) -> Vector3:
	var abs_axis := axis.abs()
	if abs_axis.x >= abs_axis.y and abs_axis.x >= abs_axis.z:
		return Vector3(signf(axis.x), 0, 0)
	if abs_axis.y >= abs_axis.z:
		return Vector3(0, signf(axis.y), 0)
	return Vector3(0, 0, signf(axis.z))


## A fixed structure with a voxel face-adjacent to `point`, on a matching grid.
static func _adjacent_structure(world: World3D, point: Vector3, size: float) -> VoxelBody:
	var tree := Engine.get_main_loop() as SceneTree
	for node in tree.get_nodes_in_group(&"voxel_bodies"):
		var body := node as VoxelBody
		if body == null or not body.freeze or body.get_world_3d() != world or not is_equal_approx(body.voxel_size, size):
			continue
		var cell := body.world_to_cell(point)
		if body.cell_to_world(cell).distance_to(point) > size * 0.35:
			continue
		for offset in VoxelBody.NEIGHBOURS:
			if body.cells.has(cell + offset):
				return body
	return null


## Whether a voxel at `centre` sits directly on non-voxel world geometry.
static func _rests_on_world(space: PhysicsDirectSpaceState3D, centre: Vector3, size: float, body: VoxelBody) -> bool:
	var exclude: Array[RID] = []
	if body != null:
		exclude.append(body.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(centre, centre + Vector3.DOWN * size * 0.75, PLACE_MASK, exclude)
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return false
	var collider: Object = hit["collider"]
	return not (collider is RigidBody3D or collider is CharacterBody3D)


## Whether the voxel's box would overlap the player or a loose prop.
static func _blocked(space: PhysicsDirectSpaceState3D, box_transform: Transform3D, size: float, body: VoxelBody) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * size * 0.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = box_transform
	query.collision_mask = BLOCK_MASK
	if body != null:
		query.exclude = [body.get_rid()]
	for result in space.intersect_shape(query, 4):
		var other: Object = result.get("collider")
		var other_body := other as RigidBody3D
		# Fixed voxel structures share the props layer; only loose bodies and the player block.
		if other_body != null and other_body.freeze:
			continue
		return true
	return false
