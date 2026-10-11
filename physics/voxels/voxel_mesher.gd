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

static var _material: StandardMaterial3D


static func get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.9
	return _material


## Returns null when the chunk has no visible faces.
static func build(chunk_cells: Dictionary, cells: Dictionary, health: Dictionary,
		palette: Array[VoxelMaterialDefinition], voxel_size: float, surface_state: Dictionary = {}) -> ArrayMesh:
	var surfaces: Dictionary = {}
	for cell: Vector3i in chunk_cells:
		var material := palette[cells[cell]]
		var mesh_material := material.mesh_material_override if material.mesh_material_override != null else get_material()
		var tool := surfaces.get(mesh_material) as SurfaceTool
		var shade := 1.0 + (_hash01(cell) - 0.5) * 2.0 * material.color_jitter
		var damage := clampf(float(health.get(cell, material.strength)) / material.strength, 0.0, 1.0)
		var color := material.color * lerpf(0.45, 1.0, damage) * shade
		color.a = 1.0
		var origin := Vector3(cell)
		for face in FACES:
			if cells.has(cell + face[0]):
				var neighbour_material := palette[cells[cell + face[0]]].mesh_material_override
				# Timber edges remain visible through adjacent glass. Faces between
				# matching glass cells and between ordinary solid cells stay culled.
				if neighbour_material == null or neighbour_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED or neighbour_material == mesh_material:
					continue
			if tool == null:
				tool = SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(mesh_material)
				surfaces[mesh_material] = tool
			var normal := Vector3(face[0])
			var corners: Array = face[1]
			var face_color := VoxelToolSurface.color(color, surface_state.get(cell, {}).get(face[0], {}))
			for index in VoxelMesher.FACE_ORDER:
				tool.set_color(face_color)
				tool.set_normal(normal)
				tool.add_vertex((origin + corners[index]) * voxel_size)
	if surfaces.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for tool: SurfaceTool in surfaces.values():
		tool.commit(mesh)
	return mesh


static func _hash01(cell: Vector3i) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (cell.z * 83492791)
	return float(absi(h) % 1000) / 999.0
