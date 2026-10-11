class_name VoxelMesher
extends RefCounted
## Builds one chunk's mesh: only faces that touch empty space, coloured per voxel
## (material colour, a stable per-voxel jitter, and darkening as health drops).

const FACES := [
	# Neighbour direction, then the face's four corners on the unit cube.
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]],
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
]

## Triangle order for each face's corners. Godot treats clockwise triangles (seen
## from outside) as front faces, which lighting, culling and GI all rely on.
const FACE_ORDER := [0, 2, 1, 0, 3, 2]
## The axis each face in FACES points along.
const _AXIS: Array[int] = [0, 0, 1, 1, 2, 2]

static var _material: StandardMaterial3D
const EMPTY := {}


static func get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.9
	return _material


## One material's geometry, gathered straight into packed arrays (much cheaper
## than a SurfaceTool call per vertex).
class _Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()


## Each face's six vertices (two triangles in FACE_ORDER) on the unit cube.
static var _face_vertices: Array[PackedVector3Array] = []


static func _prepare() -> void:
	if not _face_vertices.is_empty():
		return
	for face in FACES:
		var corners: Array = face[1]
		var ordered := PackedVector3Array()
		for index in FACE_ORDER:
			ordered.append(corners[index])
		_face_vertices.append(ordered)


## Returns null when the chunk has no visible faces. Visible faces that lie in
## the same plane and share a colour and material are merged into rectangles
## (greedy meshing), so flat painted panels cost two triangles, not two per voxel.
static func build(chunk_cells: Dictionary, cells: Dictionary, health: Dictionary,
		palette: Array[VoxelMaterialDefinition], voxel_size: float, surface_state: Dictionary = {}) -> ArrayMesh:
	return to_mesh(build_surfaces(chunk_cells, cells, health, palette, voxel_size, surface_state))


## The chunk's geometry as raw arrays, one _Surface per material (empty when
## nothing is visible). Lets callers combine chunks without reading meshes back.
static func build_surfaces(chunk_cells: Dictionary, cells: Dictionary, health: Dictionary,
		palette: Array[VoxelMaterialDefinition], voxel_size: float, surface_state: Dictionary = {}) -> Dictionary:
	_prepare()
	var has_state := not surface_state.is_empty()
	# Visible faces, per direction and slice: {Vector2i(u, v): Vector2i(colour, material)}.
	var layers: Array[Dictionary] = []
	for f in 6:
		layers.append({})
	var colors := {}
	var materials: Array[Material] = []
	for cell: Vector3i in chunk_cells:
		var material := palette[cells[cell]]
		var mesh_material := material.mesh_material_override if material.mesh_material_override != null else get_material()
		var shade := 1.0 + (_hash01(cell) - 0.5) * 2.0 * material.color_jitter
		var damage := clampf(float(health.get(cell, material.strength)) / material.strength, 0.0, 1.0)
		var color := material.color * lerpf(0.45, 1.0, damage) * shade
		color.a = 1.0
		# Most voxels carry no paint or scorch marks: skip the per-face lookups then.
		var state: Dictionary = surface_state.get(cell, EMPTY) if has_state else EMPTY
		var slot := materials.find(mesh_material)
		if slot < 0:
			materials.append(mesh_material)
			slot = materials.size() - 1
		for f in 6:
			var dir: Vector3i = FACES[f][0]
			var neighbour := cell + dir
			if cells.has(neighbour):
				var neighbour_material := palette[cells[neighbour]].mesh_material_override
				# Timber edges remain visible through adjacent glass. Faces between
				# matching glass cells and between ordinary solid cells stay culled.
				if neighbour_material == null or neighbour_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED or neighbour_material == mesh_material:
					continue
			var face_color := color if state.is_empty() else VoxelToolSurface.color(color, state.get(dir, EMPTY))
			var rgb := face_color.to_rgba32() >> 8
			colors[rgb] = face_color
			var axis := _AXIS[f]
			var slices: Dictionary = layers[f]
			var slice: Dictionary = slices.get(cell[axis], {})
			if slice.is_empty():
				slices[cell[axis]] = slice
			slice[Vector2i(cell[(axis + 1) % 3], cell[(axis + 2) % 3])] = Vector2i(rgb, slot)
	var surfaces: Dictionary = {}
	for f in 6:
		var axis := _AXIS[f]
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		var normal := Vector3(FACES[f][0])
		var unit := _face_vertices[f]
		for depth: int in layers[f]:
			var slice: Dictionary = layers[f][depth]
			for start: Vector2i in slice.keys():
				if not slice.has(start):
					continue
				var key: Vector2i = slice[start]
				# Grow along u, then whole rows along v, while the face matches.
				var width := 1
				while slice.get(start + Vector2i(width, 0)) == key:
					width += 1
				var height := 1
				var grow := true
				while grow:
					for i in width:
						if slice.get(start + Vector2i(i, height)) != key:
							grow = false
							break
					if grow:
						height += 1
				for j in height:
					for i in width:
						slice.erase(start + Vector2i(i, j))
				var mesh_material := materials[key.y]
				var surface := surfaces.get(mesh_material) as _Surface
				if surface == null:
					surface = _Surface.new()
					surfaces[mesh_material] = surface
				var origin := Vector3.ZERO
				origin[axis] = depth
				origin[u_axis] = start.x
				origin[v_axis] = start.y
				var stretch := Vector3.ONE
				stretch[u_axis] = width
				stretch[v_axis] = height
				var color: Color = colors[key.x]
				for k in 6:
					surface.vertices.append((origin + unit[k] * stretch) * voxel_size)
					surface.normals.append(normal)
					surface.colors.append(color)
	return surfaces


## Appends one set of surfaces to another (combining chunks into one mesh).
static func merge(into: Dictionary, surfaces: Dictionary) -> void:
	for mesh_material: Material in surfaces:
		var source: _Surface = surfaces[mesh_material]
		var target := into.get(mesh_material) as _Surface
		if target == null:
			target = _Surface.new()
			into[mesh_material] = target
		target.vertices.append_array(source.vertices)
		target.normals.append_array(source.normals)
		target.colors.append_array(source.colors)


## Null when there is nothing to draw.
static func to_mesh(surfaces: Dictionary) -> ArrayMesh:
	if surfaces.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for mesh_material: Material in surfaces:
		var surface: _Surface = surfaces[mesh_material]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface.vertices
		arrays[Mesh.ARRAY_NORMAL] = surface.normals
		arrays[Mesh.ARRAY_COLOR] = surface.colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mesh_material)
	return mesh


static func _hash01(cell: Vector3i) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (cell.z * 83492791)
	return float(absi(h) % 1000) / 999.0
