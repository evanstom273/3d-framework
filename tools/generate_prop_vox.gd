extends SceneTree
## Rebuilds holdable props as MagicaVoxel models from their current definitions:
## shape parts (with their materials) plus detail meshes, voxelised at a per-prop
## size. Writes props/vox/<name>.vox and points each definition's vox_model at it.
## Collision is untouched, so props behave exactly as before.
## Run: godot --headless --path . -s res://tools/generate_prop_vox.gd [-- hammer wooden_bat ...]
## (names after "--" rebuild only those models; otherwise all are rebuilt)

const OUT_DIR := "res://props/vox/"

## Definition, voxel size (m), and optional plank stripes [axis, width in voxels].
const PROPS := [
	["res://props/wooden_crate.tres", 0.03, [1, 4]],
	["res://props/rubber_ball.tres", 0.025, []],
	["res://props/ball.tres", 0.025, []],
	["res://props/metal_box.tres", 0.025, []],
	["res://props/cardboard_box.tres", 0.025, []],
	["res://props/cylinder.tres", 0.03, []],
	["res://props/wooden_block.tres", 0.02, [0, 3]],
	["res://props/open_wooden_box.tres", 0.025, [1, 3]],
	["res://props/plastic_basket.tres", 0.025, []],
	["res://props/bucket.tres", 0.02, []],
	["res://props/hammer.tres", 0.012, []],
	["res://props/golf_club.tres", 0.01, []],
	["res://props/wooden_bat.tres", 0.015, []],
	["res://props/trowel.tres", 0.01, []],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Optional names after "--" limit which models are rebuilt, e.g. "-- hammer wooden_bat",
	# so hand-edited models are left alone.
	var only := OS.get_cmdline_user_args()
	# "-- new" models every object definition under props/ that has no model yet,
	# choosing a voxel size from its size.
	if only == PackedStringArray(["new"]):
		for path in _find_definitions("res://props") + _find_definitions("res://contraptions/assets"):
			var definition := load(path) as PhysicsObjectDefinition
			if definition != null and definition.vox_model.is_empty():
				_convert(path, -1.0, [])
		quit()
		return
	for entry in PROPS:
		if not only.is_empty() and not only.has(String(entry[0]).get_file().get_basename()):
			continue
		if not ResourceLoader.exists(entry[0]):
			print("skip (missing): ", entry[0])
			continue
		_convert(entry[0], entry[1], entry[2])
	quit()


func _convert(path: String, voxel_size: float, planks: Array) -> void:
	var definition: PhysicsObjectDefinition = load(path)
	# Voxelise the original geometry, not a previously generated model.
	definition.vox_model = ""
	var primitives := _collect_primitives(definition)
	if primitives.is_empty():
		print("skip (no geometry): ", path)
		return
	var bounds: AABB = primitives[0]["bounds"]
	for primitive in primitives:
		bounds = bounds.merge(primitive["bounds"])
	if voxel_size <= 0.0:
		# Tools are slim and seen up close, so they get finer voxels (~80 along their
		# length). Props get ~32 along their longest side, but never so coarse that
		# a thin side (a plank, a pallet slat) collapses to a single voxel.
		if definition.tool != null:
			voxel_size = clampf(bounds.get_longest_axis_size() / 80.0, 0.008, 0.02)
		else:
			voxel_size = minf(bounds.get_longest_axis_size() / 32.0, bounds.get_shortest_axis_size() / 2.0)
			voxel_size = clampf(voxel_size, 0.008, 0.04)
		voxel_size = snappedf(voxel_size, 0.001)
	var dims := Vector3i((bounds.size / voxel_size).ceil())
	if dims.x > 256 or dims.y > 256 or dims.z > 256:
		push_error("%s needs %s voxels; use a larger voxel size." % [path, dims])
		return
	var cells := {}
	for x in dims.x:
		for y in dims.y:
			for z in dims.z:
				var point := bounds.position + (Vector3(x, y, z) + Vector3.ONE * 0.5) * voxel_size
				var hit := -1
				for index in primitives.size():
					if _inside(primitives[index], point, voxel_size):
						hit = index
				if hit >= 0:
					var cell := Vector3i(x, y, z)
					cells[cell] = _shade(primitives[hit]["color"], cell, hit == 0, planks)
	var name := path.get_file().get_basename()
	# Advanced tools and components keep their models together in vox/advanced/.
	var out_dir := OUT_DIR + "advanced/" if path.contains("/advanced/") or path.contains("contraptions/") else OUT_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var out_path := out_dir + name + ".vox"
	var error := VoxFile.write_cells(ProjectSettings.globalize_path(out_path), dims, cells)
	if error != OK:
		push_error("Failed to write %s (%s)" % [out_path, error_string(error)])
		return
	definition.vox_model = out_path
	definition.vox_voxel_size = voxel_size
	definition.vox_origin = bounds.position
	_save_keeping_uid(definition, path)
	print("%s -> %s  %s voxels grid, %d filled" % [name, out_path, dims, cells.size()])


## Everything that shapes the prop, in paint order (later entries colour over earlier).
func _collect_primitives(definition: PhysicsObjectDefinition) -> Array:
	var primitives := []
	var base_color := _material_color(definition.material, Color(0.6, 0.6, 0.6))
	if definition.container != null:
		# Container walls come from collision, so the model is hollow like the real thing.
		for part in definition.get_collision_parts():
			primitives.append(_from_shape(part["shape"], part["transform"], base_color))
	else:
		for part in definition.get_visual_parts():
			var mesh: Mesh = part["mesh"]
			var color := _material_color(mesh.surface_get_material(0) if mesh.get_surface_count() > 0 else null, base_color)
			if mesh is PrimitiveMesh and (mesh as PrimitiveMesh).material != null:
				color = _material_color((mesh as PrimitiveMesh).material, color)
			primitives.append(_from_mesh(mesh, part["transform"], color))
	if definition.detail_scene != null:
		var details := definition.detail_scene.instantiate()
		_collect_details(details, Transform3D.IDENTITY, primitives, base_color)
		details.free()
	return primitives.filter(func(p): return not p.is_empty())


func _collect_details(node: Node, parent_transform: Transform3D, primitives: Array, fallback: Color) -> void:
	for child in node.get_children():
		var child_transform := parent_transform
		if child is Node3D:
			child_transform = parent_transform * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mesh := (child as MeshInstance3D).mesh
			var color := fallback
			if mesh is PrimitiveMesh:
				color = _material_color((mesh as PrimitiveMesh).material, fallback)
			primitives.append(_from_mesh(mesh, child_transform, color))
		_collect_details(child, child_transform, primitives, fallback)


func _from_shape(shape: Shape3D, at: Transform3D, color: Color) -> Dictionary:
	if shape is BoxShape3D:
		return _primitive("box", {"size": (shape as BoxShape3D).size}, at, color, (shape as BoxShape3D).size)
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return _primitive("sphere", {"radius": r}, at, color, Vector3.ONE * r * 2.0)
	if shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		return _primitive("cylinder", {"top": c.radius, "bottom": c.radius, "height": c.height}, at, color, Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	if shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		return _primitive("capsule", {"radius": c.radius, "height": c.height}, at, color, Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	return {}


func _from_mesh(mesh: Mesh, at: Transform3D, color: Color) -> Dictionary:
	if mesh is BoxMesh:
		return _primitive("box", {"size": (mesh as BoxMesh).size}, at, color, (mesh as BoxMesh).size)
	if mesh is SphereMesh:
		var r := (mesh as SphereMesh).radius
		return _primitive("sphere", {"radius": r}, at, color, Vector3.ONE * r * 2.0)
	if mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		var r := maxf(c.top_radius, c.bottom_radius)
		return _primitive("cylinder", {"top": c.top_radius, "bottom": c.bottom_radius, "height": c.height}, at, color, Vector3(r * 2.0, c.height, r * 2.0))
	if mesh is CapsuleMesh:
		var c := mesh as CapsuleMesh
		return _primitive("capsule", {"radius": c.radius, "height": c.height}, at, color, Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	if mesh is TorusMesh:
		var t := mesh as TorusMesh
		var tube := (t.outer_radius - t.inner_radius) * 0.5
		return _primitive("torus", {"ring": (t.outer_radius + t.inner_radius) * 0.5, "tube": tube}, at, color, Vector3(t.outer_radius * 2.0, tube * 2.0, t.outer_radius * 2.0))
	return {}


func _primitive(kind: String, params: Dictionary, at: Transform3D, color: Color, extent: Vector3) -> Dictionary:
	return {"kind": kind, "params": params, "transform": at, "inverse": at.affine_inverse(), "color": color,
		"thinnest": minf(extent.x, minf(extent.y, extent.z)),
		"bounds": at * AABB(-extent * 0.5, extent)}


## Point-in-primitive. Parts thinner than a voxel are grown slightly so they never
## fall between grid points (a golf shaft still gets a line of voxels).
func _inside(primitive: Dictionary, point: Vector3, voxel_size: float) -> bool:
	var grow := voxel_size * 0.45 if primitive["thinnest"] < voxel_size * 1.05 else 0.0
	var p: Vector3 = primitive["inverse"] * point
	var params: Dictionary = primitive["params"]
	match primitive["kind"]:
		"box":
			var half: Vector3 = params["size"] * 0.5 + Vector3.ONE * grow
			return absf(p.x) <= half.x and absf(p.y) <= half.y and absf(p.z) <= half.z
		"sphere":
			return p.length() <= params["radius"] + grow
		"cylinder":
			var h: float = params["height"]
			if absf(p.y) > h * 0.5 + grow:
				return false
			var r := lerpf(params["bottom"], params["top"], clampf(p.y / h + 0.5, 0.0, 1.0))
			return Vector2(p.x, p.z).length() <= r + grow
		"capsule":
			var r: float = params["radius"]
			var reach := maxf(params["height"] * 0.5 - r, 0.0)
			return Vector3(p.x, p.y - clampf(p.y, -reach, reach), p.z).length() <= r + grow
		"torus":
			var ring := Vector2(p.x, p.z).length() - float(params["ring"])
			return Vector2(ring, p.y).length() <= float(params["tube"]) + grow
	return false


## Small per-voxel shade variation, plus alternating plank stripes on the main surface.
func _shade(color: Color, cell: Vector3i, is_base: bool, planks: Array) -> Color:
	var h := absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (cell.z * 83492791)) % 3
	var factor: float = [0.95, 1.0, 1.05][h]
	if is_base and planks.size() == 2 and (cell[planks[0]] / int(planks[1])) % 2 == 1:
		factor *= 0.9
	var shaded := Color(color.r * factor, color.g * factor, color.b * factor, 1.0)
	# Quantise lightly so the palette stays well under MagicaVoxel's 255 colours.
	return Color8(mini(roundi(shaded.r8 / 4.0) * 4, 255), mini(roundi(shaded.g8 / 4.0) * 4, 255), mini(roundi(shaded.b8 / 4.0) * 4, 255))


func _find_definitions(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		if sub != "vox" and sub != "details":
			found.append_array(_find_definitions(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.ends_with(".tres"):
			found.append(dir_path.path_join(file))
	return found


## Headless saves drop the file's uid, which scenes use to find it; put it back.
func _save_keeping_uid(resource: Resource, path: String) -> void:
	var original := FileAccess.get_file_as_string(path)
	var uid_match := RegEx.create_from_string("uid=\"uid://[a-z0-9]+\"").search(original.get_slice("\n", 0))
	ResourceSaver.save(resource, path)
	if uid_match == null:
		return
	var saved := FileAccess.get_file_as_string(path)
	var header := saved.get_slice("\n", 0)
	if header.contains("uid=\"uid://"):
		header = RegEx.create_from_string("uid=\"uid://[a-z0-9]+\"").sub(header, uid_match.get_string())
	else:
		header = header.trim_suffix("]") + " " + uid_match.get_string() + "]"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(header + saved.substr(saved.find("\n")))


func _material_color(material: Material, fallback: Color) -> Color:
	var standard := material as StandardMaterial3D
	return standard.albedo_color if standard != null else fallback
