class_name VoxelCollider
extends RefCounted
## Merges a chunk's voxels into as few boxes as practical (greedy expansion along
## X, then Y, then Z), so collision stays cheap as walls get chipped away.
## Same approach as the VoxelDestruction add-on's _create_shapes.


## Returns boxes as [min_cell, max_cell] pairs (inclusive).
static func merge(chunk_cells: Dictionary) -> Array:
	var visited := {}
	var boxes := []
	# VOX cells arrive grouped by colour, not position. Starting in the middle of
	# a solid run needlessly splits it, since expansion only goes along +X/+Y/+Z.
	var ordered: Array = chunk_cells.keys()
	ordered.sort()
	for cell: Vector3i in ordered:
		if visited.has(cell):
			continue
		var low := cell
		var high := cell
		for axis in 3:
			while _can_grow(chunk_cells, visited, low, high, axis):
				high[axis] += 1
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				for z in range(low.z, high.z + 1):
					visited[Vector3i(x, y, z)] = true
		boxes.append([low, high])
	return boxes


## Whether the box can extend one layer further along `axis`.
static func _can_grow(chunk_cells: Dictionary, visited: Dictionary, low: Vector3i, high: Vector3i, axis: int) -> bool:
	var layer_low := low
	var layer_high := high
	layer_low[axis] = high[axis] + 1
	layer_high[axis] = high[axis] + 1
	for x in range(layer_low.x, layer_high.x + 1):
		for y in range(layer_low.y, layer_high.y + 1):
			for z in range(layer_low.z, layer_high.z + 1):
				var cell := Vector3i(x, y, z)
				if not chunk_cells.has(cell) or visited.has(cell):
					return false
	return true
