class_name VoxelConnectivity
extends RefCounted
## Splits a voxel set into face-connected groups (6-neighbour flood fill).


static func components(cells: Dictionary) -> Array[Array]:
	var seen := {}
	var groups: Array[Array] = []
	for start: Vector3i in cells:
		if seen.has(start):
			continue
		var group: Array = [start]
		seen[start] = true
		var next := 0
		while next < group.size():
			var cell: Vector3i = group[next]
			next += 1
			for offset in VoxelBody.NEIGHBOURS:
				var neighbour := cell + offset
				if cells.has(neighbour) and not seen.has(neighbour):
					seen[neighbour] = true
					group.append(neighbour)
		groups.append(group)
	return groups
