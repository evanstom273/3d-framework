class_name VoxelToolSurface
extends RefCounted
## Sparse cell -> face direction -> surface state. Never modifies material resources.
static func rotated(faces: Dictionary, basis: Basis) -> Dictionary:
	var result = {}
	for face: Vector3i in faces:
		result[Vector3i((basis * Vector3(face)).round())] = faces[face].duplicate()
	return result

static func color(base: Color, state: Dictionary) -> Color:
	var result: Color = state.get("paint", base)
	return result.lerp(Color(0.065, 0.045, 0.025, result.a), clampf(state.get("scorch", 0.0), 0, 0.95))

static func apply(body: VoxelBody, point: Vector3, normal: Vector3, radius: float, operation: String, amount: float, paint: Color) -> void:
	var centre = body.world_to_cell(point - normal * body.voxel_size * 0.2)
	var face = Vector3i((body.global_basis.inverse() * normal).normalized().snapped(Vector3.ONE))
	# Choose just the dominant exposed face, including angled tool contacts.
	var axis = Vector3(face).abs().max_axis_index()
	var direction = Vector3i.ZERO
	direction[axis] = 1 if face[axis] >= 0 else -1
	var reach = ceili(radius / body.voxel_size)
	for x in range(-reach, reach + 1):
		for y in range(-reach, reach + 1):
			for z in range(-reach, reach + 1):
				var cell = centre + Vector3i(x, y, z)
				if not body.cells.has(cell) or body.cells.has(cell + direction): continue
				if absf(Vector3(cell - centre).dot(Vector3(direction))) > 0.1: continue
				if body.cell_to_world(cell).distance_to(point) > radius + body.voxel_size: continue
				var faces: Dictionary = body.surface_state.get(cell, {})
				var state: Dictionary = faces.get(direction, {})
				match operation:
					"paint": state["paint"] = paint
					"heat":
						state["heat"] = minf(10.0, state.get("heat", 0.0) + amount)
						state["scorch"] = minf(0.95, state.get("scorch", 0.0) + amount * 0.12)
					"wash": state.clear()
					"cool": state["heat"] = maxf(0, state.get("heat", 0.0) - amount)
				if state.is_empty(): faces.erase(direction)
				else: faces[direction] = state
				if faces.is_empty(): body.surface_state.erase(cell)
				else: body.surface_state[cell] = faces
				body._mark_dirty(cell)

static func damage(body: VoxelBody, pose: Transform3D, size: Vector3, operation: StringName, exposure: float, rate: float) -> int:
	var inverse = pose.affine_inverse()
	var bounds = (body.global_transform.affine_inverse() * pose) * AABB(-size * 0.5, size)
	var low = Vector3i((bounds.position / body.voxel_size).floor())
	var high = Vector3i((bounds.end / body.voxel_size).ceil())
	var removed = 0
	var removed_cells := {}
	var touched := false
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for z in range(low.z, high.z + 1):
				var cell = Vector3i(x, y, z)
				if not body.cells.has(cell): continue
				var local = inverse * body.cell_to_world(cell)
				if not AABB(-size * 0.5, size).grow(body.voxel_size * 0.3).has_point(local): continue
				# Work only on the exposed layer. A blade cannot damage hidden cells through a wall.
				var exposed = false
				for direction in VoxelBody.NEIGHBOURS:
					if not body.cells.has(cell + direction): exposed = true; break
				if not exposed: continue
				var material = body.palette[body.cells[cell]]
				if material.tool_profile == null: continue
				var dealt = rate * exposure * material.tool_profile.response(operation)
				if dealt <= 0: continue
				touched = true
				var remaining: float = body.health.get(cell, material.strength) - dealt
				if remaining <= 0:
					removed_cells[cell] = body.cells[cell]
					body._remove_cell(cell)
					removed += 1
				else:
					body.health[cell] = remaining
					body._mark_dirty(cell)
	if touched:
		body.tool_worked.emit(operation, pose.origin, removed_cells)
		if not removed_cells.is_empty():
			body.cells_removed.emit(removed_cells, -pose.basis.z, rate * exposure)
	return removed
